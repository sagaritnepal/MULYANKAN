import { IsString, Matches } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @Matches(/^\+977[0-9]{9,10}$/, { message: 'phone must be a +977 Nepali number' })
  phone: string;
}
