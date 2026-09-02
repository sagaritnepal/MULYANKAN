import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

export class RegisterEmailDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  password: string;

  @IsOptional()
  @IsString()
  name?: string;
}
