import { IsOptional, IsString, MinLength } from 'class-validator';

export class CreateShowroomDto {
  @IsString()
  @MinLength(2)
  name: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  district?: string;
}
