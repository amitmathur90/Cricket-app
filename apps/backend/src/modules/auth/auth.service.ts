import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { IsNull, MoreThan, Repository } from 'typeorm';
import { OrgRole } from '../../common/enums/org-role.enum';
import {
  OrgMembership,
  OrgMembershipStatus,
} from '../../database/entities/org-membership.entity';
import { MobileLoginOtp } from '../../database/entities/mobile-login-otp.entity';
import { PasswordResetToken } from '../../database/entities/password-reset-token.entity';
import { RefreshToken } from '../../database/entities/refresh-token.entity';
import { User } from '../../database/entities/user.entity';
import { MailService } from '../mail/mail.service';
import { SmsService } from '../sms/sms.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAccessPayload } from './strategies/jwt.strategy';

const BCRYPT_SALT_ROUNDS = 12;
const OTP_TTL_MS = 10 * 60 * 1000;
const RESET_TOKEN_TTL_MS = 10 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;
/** Generic response for every forgot-password request, found account or not — never reveals whether the identifier matched a real account. */
const GENERIC_RESET_REQUESTED_MESSAGE =
  'If an account matches that email or phone number, a password reset code has been sent.';
/** Same anti-enumeration message for a mobile-OTP login request, whether or not the phone matches a real account. */
const GENERIC_LOGIN_OTP_REQUESTED_MESSAGE = 'If that mobile number matches an account, a login code has been sent.';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface SafeUser {
  id: string;
  email: string;
  fullName: string;
  isSuperAdmin: boolean;
}

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(OrgMembership)
    private readonly membershipRepo: Repository<OrgMembership>,
    @InjectRepository(RefreshToken)
    private readonly refreshTokenRepo: Repository<RefreshToken>,
    @InjectRepository(PasswordResetToken)
    private readonly passwordResetTokenRepo: Repository<PasswordResetToken>,
    @InjectRepository(MobileLoginOtp)
    private readonly mobileLoginOtpRepo: Repository<MobileLoginOtp>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly mailService: MailService,
    private readonly smsService: SmsService,
  ) {}

  async register(dto: RegisterDto): Promise<{ user: SafeUser } & AuthTokens> {
    const existing = await this.userRepo.findOne({ where: { email: dto.email } });
    if (existing) {
      throw new ConflictException('An account with this email already exists');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_SALT_ROUNDS);
    let user: User;
    try {
      user = await this.userRepo.save(
        this.userRepo.create({
          email: dto.email,
          passwordHash,
          fullName: dto.fullName,
          phone: dto.phone ? SmsService.normalizePhone(dto.phone) : null,
        }),
      );
    } catch (err) {
      // Race with another concurrent registration for the same email
      // (e.g. a double-submitted request) — the pre-check above can't
      // fully close this gap, so translate the DB-level conflict too.
      if ((err as { code?: string }).code === '23505') {
        throw new ConflictException('An account with this email already exists');
      }
      throw err;
    }

    const tokens = await this.issueTokensForUser(user);
    return { user: this.toSafeUser(user), ...tokens };
  }

  async login(dto: LoginDto): Promise<{ user: SafeUser } & AuthTokens> {
    const user = await this.userRepo.findOne({ where: { email: dto.email } });
    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const passwordMatches = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const tokens = await this.issueTokensForUser(user);
    return { user: this.toSafeUser(user), ...tokens };
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    const tokenHash = this.hashToken(refreshToken);
    const existing = await this.refreshTokenRepo.findOne({ where: { tokenHash } });

    if (!existing) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (existing.revokedAt) {
      // Reuse of an already-rotated/revoked token — treat as a possible
      // token theft and revoke the whole chain for this user.
      await this.refreshTokenRepo.update(
        { userId: existing.userId, revokedAt: IsNull() },
        { revokedAt: new Date() },
      );
      throw new UnauthorizedException('Refresh token reuse detected; all sessions revoked');
    }

    if (existing.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    const user = await this.userRepo.findOne({ where: { id: existing.userId } });
    if (!user) {
      throw new UnauthorizedException('User no longer exists');
    }

    // Rotate: revoke the used token, issue a brand new pair.
    existing.revokedAt = new Date();
    await this.refreshTokenRepo.save(existing);

    return this.issueTokensForUser(user);
  }

  async selectOrg(userId: string, organizationId: string): Promise<{ accessToken: string }> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User no longer exists');
    }

    if (!user.isSuperAdmin) {
      const membership = await this.membershipRepo.findOne({
        where: { userId, organizationId, status: OrgMembershipStatus.ACTIVE },
      });
      if (!membership) {
        throw new ForbiddenException('Not an active member of this organization');
      }
      return { accessToken: this.signAccessToken(user, organizationId, membership.role) };
    }

    // Super admins can select any org without an explicit membership row.
    const membership = await this.membershipRepo.findOne({ where: { organizationId } });
    return {
      accessToken: this.signAccessToken(user, organizationId, membership?.role ?? OrgRole.VIEWER),
    };
  }

  private async issueTokensForUser(user: User): Promise<AuthTokens> {
    const activeMemberships = await this.membershipRepo.find({
      where: { userId: user.id, status: OrgMembershipStatus.ACTIVE },
    });

    // Auto-select the org context only when unambiguous (exactly one active
    // membership). Otherwise the client must call POST /auth/select-org.
    const soleMembership = activeMemberships.length === 1 ? activeMemberships[0] : undefined;

    const accessToken = this.signAccessToken(
      user,
      soleMembership?.organizationId ?? null,
      soleMembership?.role ?? null,
    );
    const refreshToken = await this.issueRefreshToken(user.id);

    return { accessToken, refreshToken };
  }

  private signAccessToken(user: User, activeOrgId: string | null, role: OrgRole | null): string {
    const payload: JwtAccessPayload = {
      sub: user.id,
      isSuperAdmin: user.isSuperAdmin,
      activeOrgId,
      role,
    };
    return this.jwtService.sign(payload, {
      secret: this.configService.get<string>('jwt.accessSecret') as string,
      expiresIn: this.configService.get<string>('jwt.accessTtl'),
    });
  }

  private async issueRefreshToken(userId: string): Promise<string> {
    const rawToken = crypto.randomBytes(64).toString('hex');
    const tokenHash = this.hashToken(rawToken);
    const ttl = this.configService.get<string>('jwt.refreshTtl') ?? '30d';

    await this.refreshTokenRepo.save(
      this.refreshTokenRepo.create({
        userId,
        tokenHash,
        expiresAt: new Date(Date.now() + this.parseTtlMs(ttl)),
      }),
    );

    return rawToken;
  }

  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /** Resolves a "Forgot password" identifier to a User — an email (matched
   * as-typed) or a phone number (normalized the same way register/updateMe
   * store it, so "+91 98765 43210" matches a stored "9876543210"). */
  private async findUserByIdentifier(identifier: string): Promise<User | null> {
    const trimmed = identifier.trim();
    if (trimmed.includes('@')) {
      return this.userRepo.findOne({ where: { email: trimmed } });
    }
    return this.userRepo.findOne({ where: { phone: SmsService.normalizePhone(trimmed) } });
  }

  /**
   * Step 1 of "Forgot password" — looks the account up by email OR phone
   * (see RegisterDto.phone), generates a 6-digit OTP, and emails it. Always
   * returns the same generic message whether or not a matching account
   * exists, to avoid leaking which emails/phone numbers are registered.
   * Any previous, still-open request for this user is superseded (not
   * strictly deleted — just left to expire) by simply inserting a fresh
   * row; verifyPasswordResetOtp only ever considers the most recent one.
   */
  async requestPasswordReset(identifier: string): Promise<{ message: string }> {
    const user = await this.findUserByIdentifier(identifier);

    if (user) {
      const otp = crypto.randomInt(100000, 1000000).toString();
      await this.passwordResetTokenRepo.save(
        this.passwordResetTokenRepo.create({
          userId: user.id,
          otpHash: this.hashToken(otp),
          otpExpiresAt: new Date(Date.now() + OTP_TTL_MS),
        }),
      );
      await this.mailService.sendPasswordResetOtp(user.email, otp);
    }

    return { message: GENERIC_RESET_REQUESTED_MESSAGE };
  }

  /**
   * Step 2 — verifies the OTP for whichever account [identifier] resolves
   * to, against the most recent not-yet-consumed request for that user.
   * On success, mints a separate opaque reset token (never the OTP itself)
   * that resetPassword requires — this is what stands between "guessed a
   * 6-digit code" and "can actually change the password", and gives the
   * client a bearer credential for step 3 without re-sending the OTP.
   */
  async verifyPasswordResetOtp(identifier: string, otp: string): Promise<{ resetToken: string }> {
    const user = await this.findUserByIdentifier(identifier);
    // Same invalid-OTP message whether the account doesn't exist or the
    // code is simply wrong — again, don't leak which identifiers are real.
    const invalid = () => new UnauthorizedException('Invalid or expired code');
    if (!user) {
      throw invalid();
    }

    const request = await this.passwordResetTokenRepo.findOne({
      where: { userId: user.id, consumedAt: IsNull(), otpExpiresAt: MoreThan(new Date()) },
      order: { createdAt: 'DESC' },
    });
    if (!request || request.otpVerifiedAt) {
      throw invalid();
    }
    if (request.otpAttempts >= MAX_OTP_ATTEMPTS) {
      throw new UnauthorizedException('Too many attempts — request a new code');
    }

    if (request.otpHash !== this.hashToken(otp)) {
      request.otpAttempts += 1;
      await this.passwordResetTokenRepo.save(request);
      throw invalid();
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    request.otpVerifiedAt = new Date();
    request.resetTokenHash = this.hashToken(resetToken);
    request.resetTokenExpiresAt = new Date(Date.now() + RESET_TOKEN_TTL_MS);
    await this.passwordResetTokenRepo.save(request);

    return { resetToken };
  }

  /**
   * Step 3 — consumes the reset token from verifyPasswordResetOtp and sets
   * the new password. Also revokes every existing refresh token for the
   * user (forces re-login on all devices), the same reasonable security
   * posture as a real password change should have.
   */
  async resetPassword(resetToken: string, newPassword: string): Promise<{ message: string }> {
    const resetTokenHash = this.hashToken(resetToken);
    const request = await this.passwordResetTokenRepo.findOne({
      where: {
        resetTokenHash,
        consumedAt: IsNull(),
        resetTokenExpiresAt: MoreThan(new Date()),
      },
    });
    if (!request) {
      throw new BadRequestException('Invalid or expired reset token');
    }

    const user = await this.userRepo.findOne({ where: { id: request.userId } });
    if (!user) {
      throw new BadRequestException('Invalid or expired reset token');
    }

    user.passwordHash = await bcrypt.hash(newPassword, BCRYPT_SALT_ROUNDS);
    await this.userRepo.save(user);

    request.consumedAt = new Date();
    await this.passwordResetTokenRepo.save(request);

    await this.refreshTokenRepo.update(
      { userId: user.id, revokedAt: IsNull() },
      { revokedAt: new Date() },
    );

    return { message: 'Password reset successfully' };
  }

  /**
   * Step 1 of "Login with mobile OTP" — texts a 6-digit OTP to the account
   * matching this phone number, via SmsService (Renflair). Always returns
   * the same generic message whether or not a matching account exists,
   * same anti-enumeration posture as requestPasswordReset.
   */
  async requestMobileLoginOtp(phone: string): Promise<{ message: string }> {
    const normalizedPhone = SmsService.normalizePhone(phone);
    const user = await this.userRepo.findOne({ where: { phone: normalizedPhone } });

    if (user) {
      const otp = crypto.randomInt(100000, 1000000).toString();
      await this.mobileLoginOtpRepo.save(
        this.mobileLoginOtpRepo.create({
          userId: user.id,
          otpHash: this.hashToken(otp),
          otpExpiresAt: new Date(Date.now() + OTP_TTL_MS),
        }),
      );
      await this.smsService.sendOtp(normalizedPhone, otp);
    }

    return { message: GENERIC_LOGIN_OTP_REQUESTED_MESSAGE };
  }

  /**
   * Step 2 — verifies the OTP against the most recent not-yet-consumed
   * request for the account matching [phone]. Unlike the password-reset
   * OTP (which only unlocks a further reset-token step), success here
   * directly issues real access/refresh tokens via issueTokensForUser —
   * the same tokens a password login would produce — since there's no
   * further step needed to "log in".
   */
  async verifyMobileLoginOtp(phone: string, otp: string): Promise<{ user: SafeUser } & AuthTokens> {
    const normalizedPhone = SmsService.normalizePhone(phone);
    const invalid = () => new UnauthorizedException('Invalid or expired code');

    const user = await this.userRepo.findOne({ where: { phone: normalizedPhone } });
    if (!user) {
      throw invalid();
    }

    const request = await this.mobileLoginOtpRepo.findOne({
      where: { userId: user.id, consumedAt: IsNull(), otpExpiresAt: MoreThan(new Date()) },
      order: { createdAt: 'DESC' },
    });
    if (!request) {
      throw invalid();
    }
    if (request.otpAttempts >= MAX_OTP_ATTEMPTS) {
      throw new UnauthorizedException('Too many attempts — request a new code');
    }

    if (request.otpHash !== this.hashToken(otp)) {
      request.otpAttempts += 1;
      await this.mobileLoginOtpRepo.save(request);
      throw invalid();
    }

    request.consumedAt = new Date();
    await this.mobileLoginOtpRepo.save(request);

    const tokens = await this.issueTokensForUser(user);
    return { user: this.toSafeUser(user), ...tokens };
  }

  /** Parses simple durations like "30d", "15m", "12h", "45s" into milliseconds. */
  private parseTtlMs(ttl: string): number {
    const match = /^(\d+)\s*(ms|s|m|h|d)$/.exec(ttl.trim());
    if (!match) {
      return 30 * 24 * 60 * 60 * 1000; // default 30 days
    }
    const value = parseInt(match[1], 10);
    const unit = match[2];
    const unitMs: Record<string, number> = {
      ms: 1,
      s: 1000,
      m: 60 * 1000,
      h: 60 * 60 * 1000,
      d: 24 * 60 * 60 * 1000,
    };
    return value * unitMs[unit];
  }

  private toSafeUser(user: User): SafeUser {
    return {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      isSuperAdmin: user.isSuperAdmin,
    };
  }
}
