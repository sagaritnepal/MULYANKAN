/**
 * One-off fixup for the 10 hamroauto.com.np requests seeded before the
 * draft status existed: resets them to 'draft' (countdown cleared) and
 * rewrites their photo URLs to go through /media/proxy (the source has
 * no CORS headers, so a browser blocks them hotlinked directly).
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const PROXY_BASE = process.env.PROXY_BASE ?? 'http://localhost:3000/api/media/proxy';

async function main() {
  const showroom = await prisma.showroom.findFirst({ where: { name: 'HAMRO G&G' } });
  if (!showroom) {
    console.log('No HAMRO G&G showroom found — nothing to reset.');
    return;
  }

  const requests = await prisma.valuationRequest.findMany({
    where: { showroomId: showroom.id },
    include: { photos: true },
  });

  for (const r of requests) {
    await prisma.valuationRequest.update({
      where: { id: r.id },
      data: { status: 'draft', closesAt: null, closedAt: null, escalatedAt: null },
    });

    for (const photo of r.photos) {
      if (photo.url.startsWith(PROXY_BASE)) continue;
      const proxied = `${PROXY_BASE}?src=${encodeURIComponent(photo.url)}`;
      await prisma.requestPhoto.update({ where: { id: photo.id }, data: { url: proxied } });
    }
  }

  console.log(`Reset ${requests.length} requests to draft and proxied their photo URLs.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
