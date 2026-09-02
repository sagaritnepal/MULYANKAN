import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

@Injectable()
export class StorageService {
  private client: S3Client;
  private bucket: string;
  private publicBaseUrl: string;

  constructor(private config: ConfigService) {
    this.bucket = this.config.get<string>('S3_BUCKET')!;
    this.publicBaseUrl = this.config.get<string>('S3_PUBLIC_BASE_URL')!;
    this.client = new S3Client({
      endpoint: this.config.get<string>('S3_ENDPOINT'),
      region: this.config.get<string>('S3_REGION') ?? 'auto',
      forcePathStyle: this.config.get('S3_FORCE_PATH_STYLE') === 'true',
      credentials: {
        accessKeyId: this.config.get<string>('S3_ACCESS_KEY_ID')!,
        secretAccessKey: this.config.get<string>('S3_SECRET_ACCESS_KEY')!,
      },
    });
  }

  /**
   * Returns a short-lived presigned PUT URL so the device can upload the
   * (already client-compressed) file directly to object storage, in
   * parallel with other photos, without routing bytes through the API.
   */
  async presignUpload(folder: string, contentType: string) {
    const ext = extensionFor(contentType);
    const key = `${folder}/${randomUUID()}${ext}`;
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });
    const uploadUrl = await getSignedUrl(this.client, command, { expiresIn: 300 });
    return { uploadUrl, key, publicUrl: `${this.publicBaseUrl}/${key}` };
  }
}

function extensionFor(contentType: string): string {
  if (contentType === 'image/jpeg') return '.jpg';
  if (contentType === 'image/png') return '.png';
  if (contentType === 'image/webp') return '.webp';
  if (contentType === 'audio/mp4' || contentType === 'audio/m4a') return '.m4a';
  if (contentType === 'audio/aac') return '.aac';
  return '';
}
