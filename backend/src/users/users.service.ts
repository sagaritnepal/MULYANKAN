import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateMeDto } from './dto/update-me.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  findWithRoles(userId: string) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { roleAssignments: true },
    });
  }

  updateMe(userId: string, dto: UpdateMeDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
      include: { roleAssignments: true },
    });
  }
}
