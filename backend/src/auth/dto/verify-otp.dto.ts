import { IsOptional, IsString, Matches, Length } from 'class-validator';

export class VerifyOtpDto {
  @IsString()
  @Matches(/^\+977[0-9]{9,10}$/, { message: 'phone must be a +977 Nepali number' })
  phone: string;

  @IsString()
  @Length(4, 8)
  code: string;

  @IsOptional()
  @IsString()
  name?: string;
}
