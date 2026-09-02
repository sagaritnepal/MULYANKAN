import { Module } from '@nestjs/common';
import { QuotesController } from './quotes.controller';
import { QuotesService } from './quotes.service';
import { RealtimeModule } from '../realtime/realtime.module';
import { LiveBiddingModule } from '../live-bidding/live-bidding.module';

@Module({
  imports: [RealtimeModule, LiveBiddingModule],
  controllers: [QuotesController],
  providers: [QuotesService],
})
export class QuotesModule {}
