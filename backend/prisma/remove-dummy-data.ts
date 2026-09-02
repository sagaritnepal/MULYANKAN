/**
 * One-off cleanup: removes the two fake showrooms (Kathmandu Bike Traders,
 * Pokhara Recon Center) and their sample requests created by seed-dev.ts.
 * These were only ever meant to give the real test account (HAMRO G&G)
 * something to see in its Inbox before real cross-showroom traffic existed
 * — now that real users are on the app, they just show up as noise.
 *
 * Run with: npx ts-node prisma/remove-dummy-data.ts
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const DUMMY_SHOWROOM_NAMES = ['Kathmandu Bike Traders', 'Pokhara Recon Center'];
const DUMMY_PHONES = ['+9779811100001', '+9779811100002'];

async function main() {
  const showrooms = await prisma.showroom.findMany({ where: { name: { in: DUMMY_SHOWROOM_NAMES } } });
  const showroomIds = showrooms.map((s) => s.id);
  const users = await prisma.user.findMany({ where: { phone: { in: DUMMY_PHONES } } });
  const userIds = users.map((u) => u.id);

  if (showroomIds.length === 0 && userIds.length === 0) {
    console.log('No dummy data found — nothing to remove.');
    return;
  }

  const requests = await prisma.valuationRequest.findMany({
    where: { showroomId: { in: showroomIds } },
    select: { id: true },
  });
  const requestIds = requests.map((r) => r.id);

  const notifCount = await prisma.notification.deleteMany({
    where: { OR: [{ userId: { in: userIds } }, { requestId: { in: requestIds } }] },
  });

  const requestDelete = await prisma.valuationRequest.deleteMany({ where: { id: { in: requestIds } } });

  // Quotes those dummy users placed on anyone else's (real) requests too —
  // shouldn't exist in practice, but clear them so the user delete below
  // doesn't fail on a stray FK.
  const strayQuotes = await prisma.quote.deleteMany({ where: { valuerUserId: { in: userIds } } });

  await prisma.user.updateMany({ where: { id: { in: userIds } }, data: { showroomId: null } });
  const showroomDelete = await prisma.showroom.deleteMany({ where: { id: { in: showroomIds } } });
  const userDelete = await prisma.user.deleteMany({ where: { id: { in: userIds } } });

  console.log('Removed dummy data:');
  console.log(`  ${requestDelete.count} valuation requests (and their photos/quotes/decisions)`);
  console.log(`  ${strayQuotes.count} stray quotes on other requests`);
  console.log(`  ${notifCount.count} notifications`);
  console.log(`  ${showroomDelete.count} showrooms`);
  console.log(`  ${userDelete.count} users`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
