import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { User } from '@prisma/client';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { UpdateMeDto } from './dto/update-me.dto';
import { serializeUser } from './user.serializer';

@UseGuards(JwtAuthGuard)
@Controller()
export class UsersController {
  constructor(private users: UsersService) {}

  @Get('me')
  async me(@CurrentUser() user: User) {
    return serializeUser(await this.users.findWithRoles(user.id));
  }

  @Patch('me')
  async updateMe(@CurrentUser() user: User, @Body() dto: UpdateMeDto) {
    const updated = await this.users.updateMe(user.id, dto);
    return serializeUser(updated);
  }
}
