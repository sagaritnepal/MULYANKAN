import { Injectable, Logger } from '@nestjs/common';
import { EmailProvider } from './email-provider.interface';

/**
 * Dev/local fallback: logs the reset code instead of emailing it — same
 * role as ConsoleSmsProvider for OTP. No SMTP/SendGrid credentials are
 * configured yet, so this is the only provider wired up for now; swap in
 * a real one (e.g. an SmtpEmailProvider) behind EmailProvider the same
 * way SparrowSmsProvider plugs into SmsProvider.
 */
@Injectable()
export class ConsoleEmailProvider implements EmailProvider {
  private readonly logger = new Logger('PasswordReset');

  async sendPasswordResetCode(email: string, code: string): Promise<void> {
    this.logger.warn(`[DEV RESET CODE] ${email} -> ${code} (no email provider configured)`);
  }
}
