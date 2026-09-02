import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { SMS_PROVIDER } from './otp/sms-provider.interface';
import { ConsoleSmsProvider } from './otp/console-sms.provider';
import { SparrowSmsProvider } from './otp/sparrow-sms.provider';
import { EMAIL_PROVIDER } from './email/email-provider.interface';
import { ConsoleEmailProvider } from './email/console-email.provider';

@Module({
  imports: [JwtModule.register({ global: true })],
  controllers: [AuthController],
  providers: [
    AuthService,
    ConsoleSmsProvider,
    SparrowSmsProvider,
    ConsoleEmailProvider,
    {
      provide: SMS_PROVIDER,
      inject: [ConfigService, ConsoleSmsProvider, SparrowSmsProvider],
      useFactory: (config: ConfigService, dev: ConsoleSmsProvider, sparrow: SparrowSmsProvider) =>
        config.get('OTP_PROVIDER') === 'sparrow' ? sparrow : dev,
    },
    {
      // No real email provider (SMTP/SendGrid) is wired up yet — always
      // the console dev provider for now. See ConsoleEmailProvider.
      provide: EMAIL_PROVIDER,
      useExisting: ConsoleEmailProvider,
    },
  ],
  exports: [AuthService],
})
export class AuthModule {}
