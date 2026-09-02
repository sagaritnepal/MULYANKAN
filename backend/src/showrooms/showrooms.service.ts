import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ShowroomsService {
  constructor(private prisma: PrismaService) {}

  async create(ownerUserId: string, name: string, address?: string, district?: string) {
    const joinCode = randomBytes(4).toString('hex').toUpperCase();
    const showroom = await this.prisma.showroom.create({
      data: { name, address, district, joinCode, ownerUserId },
    });
    // Every user already gets both poster and valuer roles at signup
    // (see AuthService.verifyOtp), so joining a showroom only needs to
    // set showroomId — no role bookkeeping required here.
    await this.prisma.user.update({
      where: { id: ownerUserId },
      data: { showroomId: showroom.id },
    });
    return showroom;
  }

  async join(userId: string, joinCode: string) {
    const showroom = await this.prisma.showroom.findUnique({ where: { joinCode } });
    if (!showroom) throw new NotFoundException('No showroom with that join code');
    return this.prisma.user.update({ where: { id: userId }, data: { showroomId: showroom.id } });
  }

  async mine(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.showroomId) return null;
    return this.prisma.showroom.findUnique({ where: { id: user.showroomId } });
  }

  async requireShowroomId(userId: string): Promise<string> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.showroomId) {
      throw new BadRequestException('Join or create a showroom first');
    }
    return user.showroomId;
  }
}
