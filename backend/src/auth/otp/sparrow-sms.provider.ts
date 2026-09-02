import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SmsProvider } from './sms-provider.interface';

/**
 * Real Nepali OTP delivery via Sparrow SMS (https://sparrowsms.com).
 * Swap for another gateway (Aakash SMS etc.) by implementing SmsProvider
 * and switching OTP_PROVIDER in .env — nothing else in the app changes.
 */
@Injectable()
export class SparrowSmsProvider implements SmsProvider {
  private readonly logger = new Logger('OTP');

  constructor(private config: ConfigService) {}

  async send(phoneE164: string, code: string): Promise<void> {
    const token = this.config.get<string>('SPARROW_SMS_TOKEN');
    const from = this.config.get<string>('SPARROW_SMS_FROM');
    if (!token || !from) {
      throw new InternalServerErrorException('Sparrow SMS is not configured');
    }

    // Sparrow expects a local 10-digit number, not the +977 prefix.
    const localNumber = phoneE164.replace(/^\+?977/, '');
    const text = `${code} is your Mulyankan verification code. Valid for a few minutes. Do not share it.`;

    const url = new URL('https://api.sparrowsms.com/v2/sms/');
    url.searchParams.set('token', token);
    url.searchParams.set('from', from);
    url.searchParams.set('to', localNumber);
    url.searchParams.set('text', text);

    const res = await fetch(url.toString(), { method: 'POST' });
    if (!res.ok) {
      const body = await res.text().catch(() => '');
      this.logger.error(`Sparrow SMS send failed: ${res.status} ${body}`);
      throw new InternalServerErrorException('Failed to send OTP SMS');
    }
  }
}
