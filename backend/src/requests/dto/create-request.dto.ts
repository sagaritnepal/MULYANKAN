import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

const BRANDS = [
  'Bajaj',
  'Honda',
  'Hero',
  'Yamaha',
  'TVS',
  'Royal Enfield',
  'KTM',
  'Suzuki',
  'Aprilia',
  'Benelli',
  'CFMoto',
  'Other',
];

class PhotoInput {
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

class AudioInput {
  @IsString()
  url: string;

  @IsInt()
  @Min(1)
  durationMs: number;
}

export class CreateRequestDto {
  @IsIn(BRANDS)
  brand: string;

  @IsString()
  @MinLength(1)
  model: string;

  @IsOptional()
  @IsInt()
  @Min(50)
  engineCc?: number;

  @IsInt()
  @Min(1950)
  mfgYearAd: number;

  @IsOptional()
  @IsInt()
  mfgYearBs?: number;

  @IsOptional()
  @IsInt()
  regYearAd?: number;

  @IsOptional()
  @IsInt()
  regYearBs?: number;

  @IsString()
  @MinLength(3)
  plateNumber: string;

  @IsOptional()
  @IsString()
  regZone?: string;

  @IsInt()
  @Min(0)
  kmRun: number;

  @IsInt()
  @Min(1)
  ownerCount: number;

  @IsIn(['original', 'copy', 'blue_book_only', 'missing'])
  billBookStatus: string;

  @IsOptional()
  @IsString()
  taxClearedUntilBs?: string;

  @IsOptional()
  @IsISO8601()
  insuranceValidUntil?: string;

  @IsIn(['none', 'minor', 'major'])
  accidentHistory: string;

  @IsOptional()
  @IsString()
  accidentNotes?: string;

  @IsIn(['stock', 'modified'])
  modifications: string;

  @IsOptional()
  @IsString()
  modificationNotes?: string;

  @IsOptional()
  @IsString()
  colour?: string;

  @IsOptional()
  @IsString()
  conditionNotes?: string;

  @IsOptional()
  @IsString()
  maintenanceNotes?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  customerAskingPrice?: number;

  @IsOptional()
  @IsString()
  targetBikeDescription?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  targetBikePrice?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  customerTopup?: number;

  @IsIn(['now', 'later'])
  urgency: string;

  @IsOptional()
  @IsIn([180, 300, 600])
  windowSeconds?: number;

  @IsOptional()
  @IsBoolean()
  force?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => PhotoInput)
  photos?: PhotoInput[];

  @IsOptional()
  @ValidateNested()
  @Type(() => AudioInput)
  audio?: AudioInput;
}
