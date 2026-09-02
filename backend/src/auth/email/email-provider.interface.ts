export const EMAIL_PROVIDER = 'EMAIL_PROVIDER';

export interface EmailProvider {
  sendPasswordResetCode(email: string, code: string): Promise<void>;
}
