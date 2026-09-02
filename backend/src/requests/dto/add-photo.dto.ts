import { IsIn, IsInt, IsOptional, IsString } from 'class-validator';

export class AddPhotoDto {
  @IsIn(['front', 'left', 'right', 'rear', 'odometer', 'billbook', 'tax_clearance', 'extra'])
  type: string;

  @IsString()
  url: string;

  @IsOptional()
  @IsString()
  thumbUrl?: string;

  @IsOptional()
  @IsInt()
  bytes?: number;
}
