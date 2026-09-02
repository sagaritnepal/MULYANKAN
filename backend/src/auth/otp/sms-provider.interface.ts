export const SMS_PROVIDER = 'SMS_PROVIDER';

export interface SmsProvider {
  send(phoneE164: string, code: string): Promise<void>;
}
