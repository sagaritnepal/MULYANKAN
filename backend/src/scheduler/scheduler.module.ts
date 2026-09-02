import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { RequestsSchedulerService } from './requests-scheduler.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { RealtimeModule } from '../realtime/realtime.module';
import { RequestsModule } from '../requests/requests.module';

@Module({
  imports: [ScheduleModule.forRoot(), NotificationsModule, RealtimeModule, RequestsModule],
  providers: [RequestsSchedulerService],
})
export class SchedulerModule {}
