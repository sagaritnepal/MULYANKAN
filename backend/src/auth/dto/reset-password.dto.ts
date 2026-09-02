import { IsEmail, IsString, Length, MinLength } from 'class-validator';

export class ResetPasswordDto {
  @IsEmail()
  email: string;

  @IsString()
  @Length(4, 8)
  code: string;

  @IsString()
  @MinLength(8)
  newPassword: string;
}
