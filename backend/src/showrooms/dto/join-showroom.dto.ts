import { IsString } from 'class-validator';

export class JoinShowroomDto {
  @IsString()
  joinCode: string;
}
