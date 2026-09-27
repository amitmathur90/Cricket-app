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
 * Backs "Login with mobile OTP" (AuthService.requestMobileLoginOtp /
 * verifyMobileLoginOtp) — a 6-digit OTP texted via SmsService. Simpler
 * than PasswordResetToken's two-stage OTP -> reset-token lifecycle: here,
 * a successful OTP verification directly issues real access/refresh
 * tokens (the same ones a password login would), so there's no need for a
 * second opaque token in between. Never stores the OTP in plaintext, only
 * its SHA-256 hash, same convention as RefreshToken/PasswordResetToken.
 */
@Entity({ name: 'mobile_login_otps' })
export class MobileLoginOtp {
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

  @Column({ name: 'consumed_at', type: 'timestamptz', nullable: true })
  consumedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
