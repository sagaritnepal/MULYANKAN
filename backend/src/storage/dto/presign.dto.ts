import { IsIn, IsString } from 'class-validator';

export class PresignDto {
  @IsIn(['photo', 'audio'])
  kind: 'photo' | 'audio';

  @IsString()
  contentType: string;
}
