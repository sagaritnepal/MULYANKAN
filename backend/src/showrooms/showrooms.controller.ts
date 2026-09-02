import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { User } from '@prisma/client';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ShowroomsService } from './showrooms.service';
import { CreateShowroomDto } from './dto/create-showroom.dto';
import { JoinShowroomDto } from './dto/join-showroom.dto';

@UseGuards(JwtAuthGuard)
@Controller('showrooms')
export class ShowroomsController {
  constructor(private showrooms: ShowroomsService) {}

  @Post()
  create(@CurrentUser() user: User, @Body() dto: CreateShowroomDto) {
    return this.showrooms.create(user.id, dto.name, dto.address, dto.district);
  }

  @Post('join')
  join(@CurrentUser() user: User, @Body() dto: JoinShowroomDto) {
    return this.showrooms.join(user.id, dto.joinCode);
  }

  @Get('mine')
  mine(@CurrentUser() user: User) {
    return this.showrooms.mine(user.id);
  }
}
