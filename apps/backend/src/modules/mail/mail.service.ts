import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Sends transactional email via Resend's HTTPS API (https://api.resend.com)
 * — the only outbound-email path in this codebase (see NotificationsModule's
 * doc comment: everything else is in-app only). Currently used solely by
 * AuthService's forgot-password flow to deliver the OTP.
 *
 * Deliberately NOT raw SMTP: Render's outbound network silently drops SMTP
 * ports (confirmed via a real deploy — nodemailer connections to
 * smtp.hostinger.com:465 failed with ETIMEDOUT/"Connection timeout" every
 * time, a documented anti-abuse restriction on Render's plans, not
 * something fixable by changing host/port/credentials). Resend's API is
 * plain HTTPS on port 443, the same port every other outbound call this
 * backend makes already uses, so it isn't subject to that block.
 *
 * Uses the platform's native `fetch` (Node 18+) rather than adding an SDK
 * dependency for what's a single POST endpoint.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(private readonly configService: ConfigService) {}

  async sendPasswordResetOtp(toEmail: string, otp: string): Promise<void> {
    const apiKey = this.configService.get<string>('mail.resendApiKey');
    const fromName = this.configService.get<string>('mail.fromName');
    const fromEmail = this.configService.get<string>('mail.fromEmail');
    if (!apiKey) {
      throw new InternalServerErrorException('Email sending is not configured (RESEND_API_KEY missing)');
    }

    let response: Response;
    try {
      response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: `${fromName} <${fromEmail}>`,
          to: [toEmail],
          subject: 'Your password reset code',
          text: `Your password reset code is ${otp}. It expires in 10 minutes. If you did not request this, you can ignore this email.`,
          html: `<p>Your password reset code is:</p><p style="font-size:28px;font-weight:bold;letter-spacing:4px;">${otp}</p><p>This code expires in 10 minutes. If you did not request this, you can ignore this email.</p>`,
        }),
      });
    } catch (err) {
      this.logger.error(`Failed to reach Resend API for ${toEmail}: ${(err as Error).message}`);
      throw new InternalServerErrorException('Failed to send email. Please try again shortly.');
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      this.logger.error(
        `Resend API rejected password reset email to ${toEmail}: status=${response.status} body=${body}`,
      );
      throw new InternalServerErrorException('Failed to send email. Please try again shortly.');
    }
  }
}
