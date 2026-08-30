import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';

/**
 * Thin wrapper over nodemailer/SMTP — the only outbound-email path in this
 * codebase (see NotificationsModule's doc comment: everything else is
 * in-app only). Currently used solely by AuthService's forgot-password
 * flow to deliver the OTP; add methods here rather than reaching for
 * nodemailer directly elsewhere, so there's exactly one place SMTP config
 * is read from.
 *
 * The transporter is created lazily (first send) rather than in the
 * constructor, so a backend without SMTP_* env vars set (e.g. local dev)
 * can still boot — it only fails, with a clear message, if something
 * actually tries to send an email.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: Transporter | null = null;

  constructor(private readonly configService: ConfigService) {}

  private getTransporter(): Transporter {
    if (this.transporter) {
      return this.transporter;
    }
    const host = this.configService.get<string>('smtp.host');
    const user = this.configService.get<string>('smtp.user');
    const pass = this.configService.get<string>('smtp.pass');
    if (!host || !user || !pass) {
      throw new InternalServerErrorException(
        'Email sending is not configured (SMTP_HOST/SMTP_USER/SMTP_PASS missing)',
      );
    }
    this.transporter = nodemailer.createTransport({
      host,
      port: this.configService.get<number>('smtp.port'),
      secure: this.configService.get<boolean>('smtp.secure'),
      auth: { user, pass },
      // Short, explicit timeouts (nodemailer's own defaults run to several
      // minutes) so an SMTP port silently blocked by the hosting platform's
      // network (a real, fairly common restriction on free hosting tiers)
      // fails fast with a clear error instead of hanging the whole request.
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 10_000,
    });
    return this.transporter;
  }

  async sendPasswordResetOtp(toEmail: string, otp: string): Promise<void> {
    const fromName = this.configService.get<string>('smtp.fromName');
    const fromEmail = this.configService.get<string>('smtp.fromEmail');
    try {
      await this.getTransporter().sendMail({
        from: `"${fromName}" <${fromEmail}>`,
        to: toEmail,
        subject: 'Your password reset code',
        text: `Your password reset code is ${otp}. It expires in 10 minutes. If you did not request this, you can ignore this email.`,
        html: `<p>Your password reset code is:</p><p style="font-size:28px;font-weight:bold;letter-spacing:4px;">${otp}</p><p>This code expires in 10 minutes. If you did not request this, you can ignore this email.</p>`,
      });
    } catch (err) {
      const error = err as { message?: string; code?: string };
      this.logger.error(
        `Failed to send password reset email to ${toEmail}: code=${error.code ?? 'unknown'} message=${error.message ?? err}`,
      );
      throw new InternalServerErrorException('Failed to send email. Please try again shortly.');
    }
  }
}
