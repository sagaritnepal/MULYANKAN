import { Module } from '@nestjs/common';
import { RequestsController, InboxController } from './requests.controller';
import { RequestsService } from './requests.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { ShowroomsModule } from '../showrooms/showrooms.module';

@Module({
  imports: [NotificationsModule, RealtimeModule, ShowroomsModule],
  controllers: [RequestsController, InboxController],
  providers: [RequestsService],
  exports: [RequestsService],
})
export class RequestsModule {}
