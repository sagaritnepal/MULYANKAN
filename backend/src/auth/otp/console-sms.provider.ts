import { Injectable, Logger } from '@nestjs/common';
import { SmsProvider } from './sms-provider.interface';

/**
 * Dev/local fallback: logs the OTP instead of sending a real SMS, so the
 * whole auth flow works without a Sparrow SMS account. Never use in prod.
 */
@Injectable()
export class ConsoleSmsProvider implements SmsProvider {
  private readonly logger = new Logger('OTP');

  async send(phoneE164: string, code: string): Promise<void> {
    this.logger.warn(`[DEV OTP] ${phoneE164} -> ${code} (no SMS provider configured)`);
  }
}
