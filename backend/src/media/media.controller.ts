import { BadRequestException, Controller, Get, Query, Res } from '@nestjs/common';
import type { Response } from 'express';

/**
 * Some external inventory sources (e.g. hamroauto.com.np's public API)
 * serve photos with no CORS headers — fine for their own site's <img>
 * tags, but a browser blocks them when hotlinked from our own origin.
 * This proxies the bytes through our API (same-origin from the client's
 * point of view), so any of the domains below can be used as a photo URL
 * on a request without the browser refusing to load it.
 */
const ALLOWED_HOSTS = new Set(['api.hamroauto.com.np']);

@Controller('media')
export class MediaController {
  @Get('proxy')
  async proxy(@Query('src') src: string, @Res() res: Response) {
    if (!src) throw new BadRequestException('Missing src');

    let url: URL;
    try {
      url = new URL(src);
    } catch {
      throw new BadRequestException('Invalid src URL');
    }
    if (!ALLOWED_HOSTS.has(url.hostname)) {
      throw new BadRequestException('Host not allowed');
    }

    const upstream = await fetch(url.toString());
    if (!upstream.ok) {
      res.status(upstream.status).send();
      return;
    }

    const buffer = Buffer.from(await upstream.arrayBuffer());
    res.setHeader('Content-Type', upstream.headers.get('content-type') ?? 'application/octet-stream');
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.send(buffer);
  }
}
