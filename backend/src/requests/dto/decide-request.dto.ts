import { IsIn, IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class DecideRequestDto {
  @IsOptional()
  @IsUUID()
  quoteId?: string;

  @IsInt()
  @Min(0)
  offeredNpr: number;

  @IsIn(['exchanged', 'declined', 'negotiating', 'no_deal'])
  outcome: string;

  @IsOptional()
  @IsString()
  outcomeNotes?: string;
}
