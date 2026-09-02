import { Module } from '@nestjs/common';
import { LiveBiddingService } from './live-bidding.service';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [RealtimeModule],
  providers: [LiveBiddingService],
  exports: [LiveBiddingService],
})
export class LiveBiddingModule {}
