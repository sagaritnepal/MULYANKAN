import { IsBoolean, IsIn, IsOptional, IsString } from 'class-validator';

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsBoolean()
  isAvailable?: boolean;

  @IsOptional()
  @IsIn(['en', 'ne'])
  language?: string;

  @IsOptional()
  @IsString()
  fcmToken?: string;
}
