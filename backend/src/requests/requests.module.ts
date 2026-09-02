import { Module } from '@nestjs/common';
import { RequestsController, InboxController } from './requests.controller';
import { RequestsService } from './requests.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { ShowroomsModule } from '../showrooms/showrooms.module';
import { LiveBiddingModule } from '../live-bidding/live-bidding.module';

@Module({
  imports: [NotificationsModule, RealtimeModule, ShowroomsModule, LiveBiddingModule],
  controllers: [RequestsController, InboxController],
  providers: [RequestsService],
  exports: [RequestsService],
})
export class RequestsModule {}
