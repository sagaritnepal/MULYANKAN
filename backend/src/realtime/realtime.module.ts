import { Module } from '@nestjs/common';
import { RequestsGateway } from './requests.gateway';

@Module({
  providers: [RequestsGateway],
  exports: [RequestsGateway],
})
export class RealtimeModule {}
