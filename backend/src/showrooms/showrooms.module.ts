import { Module } from '@nestjs/common';
import { ShowroomsController } from './showrooms.controller';
import { ShowroomsService } from './showrooms.service';

@Module({
  controllers: [ShowroomsController],
  providers: [ShowroomsService],
  exports: [ShowroomsService],
})
export class ShowroomsModule {}
