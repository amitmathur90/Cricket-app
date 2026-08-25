import {
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
import { IsNull, Repository } from 'typeorm';
import { OrgRole } from '../../common/enums/org-role.enum';
import {
  OrgMembership,
  OrgMembershipStatus,
} from '../../database/entities/org-membership.entity';
import { RefreshToken } from '../../database/entities/refresh-token.entity';
import { User } from '../../database/entities/user.entity';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { JwtAccessPayload } from './strategies/jwt.strategy';

const BCRYPT_SALT_ROUNDS = 12;

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
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
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
