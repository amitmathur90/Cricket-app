import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from './user.entity';

/**
 * Backs the "Forgot password" flow's two-step verification: a 6-digit OTP
 * (sent by email — see MailService) that, once verified, unlocks a
 * separate opaque `resetToken` for the actual password change. Neither the
 * OTP nor the reset token is ever stored in plaintext, only their SHA-256
 * hash, same convention as RefreshToken.
 *
 * One row = one "forgot password" attempt, moving through up to two
 * stages:
 *  1. Requested: `otpHash`/`otpExpiresAt` set, everything else null.
 *  2. OTP verified: `otpVerifiedAt` set, `resetTokenHash`/
 *     `resetTokenExpiresAt` populated — this is what AuthService.
 *     resetPassword looks up.
 * `consumedAt` is set once the password has actually been changed, so a
 * given reset token can't be replayed. `otpAttempts` counts failed OTP
 * guesses so verifyPasswordResetOtp can lock a row out after too many.
 */
@Entity({ name: 'password_reset_tokens' })
export class PasswordResetToken {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'otp_hash', type: 'varchar', length: 128 })
  otpHash: string;

  @Column({ name: 'otp_expires_at', type: 'timestamptz' })
  otpExpiresAt: Date;

  @Column({ name: 'otp_attempts', type: 'int', default: 0 })
  otpAttempts: number;

  @Column({ name: 'otp_verified_at', type: 'timestamptz', nullable: true })
  otpVerifiedAt: Date | null;

  @Index()
  @Column({ name: 'reset_token_hash', type: 'varchar', length: 128, nullable: true })
  resetTokenHash: string | null;

  @Column({ name: 'reset_token_expires_at', type: 'timestamptz', nullable: true })
  resetTokenExpiresAt: Date | null;

  @Column({ name: 'consumed_at', type: 'timestamptz', nullable: true })
  consumedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
