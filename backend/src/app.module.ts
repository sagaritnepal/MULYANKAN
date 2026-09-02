import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ShowroomsModule } from './showrooms/showrooms.module';
import { RequestsModule } from './requests/requests.module';
import { QuotesModule } from './quotes/quotes.module';
import { StorageModule } from './storage/storage.module';
import { NotificationsModule } from './notifications/notifications.module';
import { RealtimeModule } from './realtime/realtime.module';
import { SchedulerModule } from './scheduler/scheduler.module';
import { MediaModule } from './media/media.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UsersModule,
    ShowroomsModule,
    RequestsModule,
    QuotesModule,
    StorageModule,
    NotificationsModule,
    RealtimeModule,
    SchedulerModule,
    MediaModule,
  ],
})
export class AppModule {}
