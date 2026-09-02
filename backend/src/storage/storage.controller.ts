import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { StorageService } from './storage.service';
import { PresignDto } from './dto/presign.dto';

@UseGuards(JwtAuthGuard)
@Controller('storage')
export class StorageController {
  constructor(private storage: StorageService) {}

  @Post('presign')
  presign(@Body() dto: PresignDto) {
    return this.storage.presignUpload(dto.kind === 'photo' ? 'photos' : 'audio', dto.contentType);
  }
}
