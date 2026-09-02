import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { randomInt } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { SMS_PROVIDER, SmsProvider } from './otp/sms-provider.interface';
import { EMAIL_PROVIDER, EmailProvider } from './email/email-provider.interface';

const OTP_RESEND_COOLDOWN_MS = 30_000;
const RESET_CODE_TTL_SECONDS = 600;
const RESET_CODE_LENGTH = 6;

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    @Inject(SMS_PROVIDER) private sms: SmsProvider,
    @Inject(EMAIL_PROVIDER) private emailProvider: EmailProvider,
  ) {}

  async requestOtp(phone: string): Promise<{ expiresInSeconds: number; devCode?: string }> {
    const recent = await this.prisma.otpCode.findFirst({
      where: { phone },
      orderBy: { createdAt: 'desc' },
    });
    if (recent && Date.now() - recent.createdAt.getTime() < OTP_RESEND_COOLDOWN_MS) {
      throw new BadRequestException('Please wait before requesting another code');
    }

    const length = Number(this.config.get('OTP_CODE_LENGTH') ?? 6);
    const ttlSeconds = Number(this.config.get('OTP_TTL_SECONDS') ?? 300);
    const code = generateNumericCode(length);
    const codeHash = await bcrypt.hash(code, 10);

    await this.prisma.otpCode.create({
      data: {
        phone,
        codeHash,
        expiresAt: new Date(Date.now() + ttlSeconds * 1000),
      },
    });

    await this.sms.send(phone, code);

    // Dev/test convenience only: with no real SMS provider configured,
    // handing the code back in the response saves digging through server
    // logs for it. Never happens once OTP_PROVIDER=sparrow is set.
    const devCode = this.config.get('OTP_PROVIDER') !== 'sparrow' ? code : undefined;
    return { expiresInSeconds: ttlSeconds, devCode };
  }

  async verifyOtp(phone: string, code: string, name?: string) {
    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) throw new UnauthorizedException('No pending code for this number');
    if (otp.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('Code expired, request a new one');
    }
    if (otp.attempts >= 5) {
      throw new UnauthorizedException('Too many attempts, request a new code');
    }

    const valid = await bcrypt.compare(code, otp.codeHash);
    if (!valid) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('Incorrect code');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { consumedAt: new Date() },
    });

    let user = await this.prisma.user.findUnique({
      where: { phone },
      include: { roleAssignments: true },
    });
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          phone,
          name: name ?? null,
          roleAssignments: { create: [{ role: 'poster' }, { role: 'valuer' }] },
        },
        include: { roleAssignments: true },
      });
    }
    if (user.status !== 'active') {
      throw new UnauthorizedException('This account has been suspended');
    }

    return { user, tokens: await this.issueTokens(user.id) };
  }

  async registerWithEmail(email: string, password: string, name?: string) {
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('An account with that email already exists');

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await this.prisma.user.create({
      data: {
        email,
        passwordHash,
        name: name ?? null,
        roleAssignments: { create: [{ role: 'poster' }, { role: 'valuer' }] },
      },
      include: { roleAssignments: true },
    });

    return { user, tokens: await this.issueTokens(user.id) };
  }

  async loginWithEmail(email: string, password: string) {
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { roleAssignments: true },
    });
    if (!user || !user.passwordHash) throw new UnauthorizedException('Incorrect email or password');
    if (user.status !== 'active') throw new UnauthorizedException('This account has been suspended');

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Incorrect email or password');

    return { user, tokens: await this.issueTokens(user.id) };
  }

  /**
   * Always returns the same shape whether or not the email exists, so a
   * caller can't use this to probe which emails are registered. `devCode`
   * only appears when there's no real email provider configured (same
   * dev/test convenience as requestOtp's devCode).
   */
  async forgotPassword(email: string): Promise<{ expiresInSeconds: number; devCode?: string }> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    const devMode = this.config.get('EMAIL_PROVIDER') !== 'smtp';

    // No account with that email — pretend to succeed (no code to reveal)
    // rather than telling the caller the email isn't registered.
    if (!user) {
      return { expiresInSeconds: RESET_CODE_TTL_SECONDS };
    }

    const recent = await this.prisma.passwordResetCode.findFirst({
      where: { email },
      orderBy: { createdAt: 'desc' },
    });
    if (recent && Date.now() - recent.createdAt.getTime() < OTP_RESEND_COOLDOWN_MS) {
      return { expiresInSeconds: RESET_CODE_TTL_SECONDS };
    }

    const code = generateNumericCode(RESET_CODE_LENGTH);
    const codeHash = await bcrypt.hash(code, 10);
    await this.prisma.passwordResetCode.create({
      data: { email, codeHash, expiresAt: new Date(Date.now() + RESET_CODE_TTL_SECONDS * 1000) },
    });
    await this.emailProvider.sendPasswordResetCode(email, code);

    return { expiresInSeconds: RESET_CODE_TTL_SECONDS, devCode: devMode ? code : undefined };
  }

  async resetPassword(email: string, code: string, newPassword: string) {
    const reset = await this.prisma.passwordResetCode.findFirst({
      where: { email, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!reset) throw new UnauthorizedException('No pending reset code for this email');
    if (reset.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('Code expired, request a new one');
    }
    if (reset.attempts >= 5) {
      throw new UnauthorizedException('Too many attempts, request a new code');
    }

    const valid = await bcrypt.compare(code, reset.codeHash);
    if (!valid) {
      await this.prisma.passwordResetCode.update({
        where: { id: reset.id },
        data: { attempts: { increment: 1 } },
      });
      throw new UnauthorizedException('Incorrect code');
    }

    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new UnauthorizedException('No account with that email');

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: user.id }, data: { passwordHash } }),
      this.prisma.passwordResetCode.update({
        where: { id: reset.id },
        data: { consumedAt: new Date() },
      }),
    ]);
  }

  async refresh(refreshToken: string) {
    let payload: { sub: string };
    try {
      payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.get('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: { roleAssignments: true },
    });
    if (!user || user.status !== 'active') throw new UnauthorizedException('Account not active');
    return { user, tokens: await this.issueTokens(user.id) };
  }

  private async issueTokens(userId: string) {
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(
        { sub: userId },
        {
          secret: this.config.get('JWT_ACCESS_SECRET'),
          expiresIn: this.config.get('JWT_ACCESS_TTL') ?? '15m',
        },
      ),
      this.jwt.signAsync(
        { sub: userId },
        {
          secret: this.config.get('JWT_REFRESH_SECRET'),
          expiresIn: this.config.get('JWT_REFRESH_TTL') ?? '30d',
        },
      ),
    ]);
    return { accessToken, refreshToken };
  }
}

function generateNumericCode(length: number): string {
  const max = 10 ** length;
  const n = randomInt(0, max);
  return n.toString().padStart(length, '0');
}
