import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface RenflairResponse {
  status?: string;
  message?: string;
}

/**
 * Sends OTP SMS via Renflair (https://sms.renflair.in) — a GET-based API
 * that embeds the OTP into their own pre-approved DLT template, so callers
 * don't need their own TRAI/DLT registration to text Indian numbers (the
 * usual blocker — see this service's sibling MailService for the equivalent
 * story with email/SMTP). Used by AuthService's mobile-OTP login flow.
 *
 * Uses the platform's native `fetch` (Node 18+) rather than an SDK, same
 * reasoning as MailService.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly configService: ConfigService) {}

  /** Strips everything but digits and keeps the last 10 — Renflair expects a
   * bare Indian mobile number ("9876543210"), no country code/symbols. This
   * also makes phone lookups tolerant of "+91...", "091...", spaces, etc. */
  static normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    return digits.slice(-10);
  }

  async sendOtp(phone: string, otp: string): Promise<void> {
    const apiKey = this.configService.get<string>('sms.renflairApiKey');
    if (!apiKey) {
      throw new InternalServerErrorException('SMS sending is not configured (RENFLAIR_API_KEY missing)');
    }
    const normalizedPhone = SmsService.normalizePhone(phone);

    let response: Response;
    try {
      const url = new URL('https://sms.renflair.in/V1.php');
      url.searchParams.set('API', apiKey);
      url.searchParams.set('PHONE', normalizedPhone);
      url.searchParams.set('OTP', otp);
      response = await fetch(url.toString());
    } catch (err) {
      this.logger.error(`Failed to reach Renflair API for ${normalizedPhone}: ${(err as Error).message}`);
      throw new InternalServerErrorException('Failed to send SMS. Please try again shortly.');
    }

    const body = (await response.json().catch(() => null)) as RenflairResponse | null;
    if (!response.ok || !body || body.status !== 'SUCCESS') {
      this.logger.error(
        `Renflair API rejected OTP SMS to ${normalizedPhone}: status=${response.status} body=${JSON.stringify(body)}`,
      );
      throw new InternalServerErrorException('Failed to send SMS. Please try again shortly.');
    }
  }
}
