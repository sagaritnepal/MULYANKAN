import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterEmailDto } from './dto/register-email.dto';
import { LoginEmailDto } from './dto/login-email.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { serializeUser } from '../users/user.serializer';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}

  @Post('otp/request')
  requestOtp(@Body() dto: RequestOtpDto) {
    return this.auth.requestOtp(dto.phone);
  }

  @Post('otp/verify')
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    const { user, tokens } = await this.auth.verifyOtp(dto.phone, dto.code, dto.name);
    return { user: serializeUser(user), ...tokens };
  }

  @Post('email/register')
  async registerEmail(@Body() dto: RegisterEmailDto) {
    const { user, tokens } = await this.auth.registerWithEmail(dto.email, dto.password, dto.name);
    return { user: serializeUser(user), ...tokens };
  }

  @Post('email/login')
  async loginEmail(@Body() dto: LoginEmailDto) {
    const { user, tokens } = await this.auth.loginWithEmail(dto.email, dto.password);
    return { user: serializeUser(user), ...tokens };
  }

  @Post('email/forgot-password')
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto.email);
  }

  @Post('email/reset-password')
  async resetPassword(@Body() dto: ResetPasswordDto) {
    await this.auth.resetPassword(dto.email, dto.code, dto.newPassword);
    return { success: true };
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshDto) {
    const { user, tokens } = await this.auth.refresh(dto.refreshToken);
    return { user: serializeUser(user), ...tokens };
  }
}
