import { IsInt, IsOptional, IsString, Min, MaxLength } from 'class-validator';

export class SubmitQuoteDto {
  @IsInt()
  @Min(1)
  amountNpr: number;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  note?: string;
}
