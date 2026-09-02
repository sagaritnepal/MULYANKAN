/**
 * One-off dev seed: creates two other showrooms (with their own posters,
 * who are also valuers per the app's dual-role model) and a handful of
 * valuation requests in different states, so the current test account's
 * Inbox and the general flow have something real to look at.
 *
 * Deliberately does NOT touch the phone number you're actually testing
 * with (+9779803250775 / HAMRO GNG) — everything here belongs to two
 * *other* showrooms, since a valuer can never see or quote on their own
 * showroom's requests (business rule #8).
 *
 * Run with: npx ts-node prisma/seed-dev.ts
 */
import { PhotoType, PrismaClient } from '@prisma/client';
import { randomBytes } from 'crypto';

const prisma = new PrismaClient();

function joinCode() {
  return randomBytes(4).toString('hex').toUpperCase();
}

async function upsertShowroomWithOwner(phone: string, ownerName: string, showroomName: string) {
  let user = await prisma.user.findUnique({ where: { phone } });
  if (!user) {
    user = await prisma.user.create({
      data: {
        phone,
        name: ownerName,
        roleAssignments: { create: [{ role: 'poster' }, { role: 'valuer' }] },
      },
    });
  }

  let showroom = await prisma.showroom.findFirst({ where: { ownerUserId: user.id } });
  if (!showroom) {
    showroom = await prisma.showroom.create({
      data: { name: showroomName, ownerUserId: user.id, joinCode: joinCode() },
    });
    await prisma.user.update({ where: { id: user.id }, data: { showroomId: showroom.id } });
  }

  return { user, showroom };
}

async function main() {
  const { user: userA, showroom: showroomA } = await upsertShowroomWithOwner(
    '+9779811100001',
    'Ram Shrestha',
    'Kathmandu Bike Traders',
  );
  const { user: userB, showroom: showroomB } = await upsertShowroomWithOwner(
    '+9779811100002',
    'Shyam Gurung',
    'Pokhara Recon Center',
  );

  const now = Date.now();
  const photo = (seed: string, type: PhotoType) => ({
    type,
    url: `https://picsum.photos/seed/${seed}/900/675`,
  });
  const PHOTO_TYPES: PhotoType[] = ['front', 'left', 'right', 'rear', 'odometer', 'billbook'];

  // 1. Live request from Showroom A — quote on this one to test the flow.
  await prisma.valuationRequest.create({
    data: {
      showroomId: showroomA.id,
      createdByUserId: userA.id,
      brand: 'Royal Enfield',
      model: 'Classic 350',
      engineCc: 349,
      mfgYearAd: 2020,
      plateNumber: 'BA 34 PA 5271',
      kmRun: 18400,
      ownerCount: 1,
      billBookStatus: 'original',
      accidentHistory: 'none',
      modifications: 'stock',
      colour: 'Stealth Black',
      customerAskingPrice: 420000,
      targetBikeDescription: 'Honda Hornet 2.0',
      targetBikePrice: 380000,
      customerTopup: 50000,
      urgency: 'now',
      windowSeconds: 300,
      status: 'live',
      closesAt: new Date(now + 5 * 60 * 1000),
      photos: {
        create: PHOTO_TYPES.map((t) =>
          photo(`re-classic-${t}`, t),
        ),
      },
    },
  });

  // 2. Live request from Showroom B.
  await prisma.valuationRequest.create({
    data: {
      showroomId: showroomB.id,
      createdByUserId: userB.id,
      brand: 'Honda',
      model: 'CB Hornet 160R',
      engineCc: 162,
      mfgYearAd: 2021,
      plateNumber: 'GA 2 KHA 1122',
      kmRun: 9200,
      ownerCount: 1,
      billBookStatus: 'original',
      accidentHistory: 'minor',
      accidentNotes: 'Small scratch on the tank, repainted',
      modifications: 'stock',
      colour: 'Athletic Blue',
      customerAskingPrice: 285000,
      urgency: 'later',
      windowSeconds: 300,
      status: 'live',
      closesAt: new Date(now + 5 * 60 * 1000),
      photos: {
        create: PHOTO_TYPES.map((t) =>
          photo(`honda-hornet-${t}`, t),
        ),
      },
    },
  });

  // 3. Closed request (window already ended) from Showroom A, with a quote
  //    from userB — so you can see a "closed, awaiting decision" state.
  const closedRequest = await prisma.valuationRequest.create({
    data: {
      showroomId: showroomA.id,
      createdByUserId: userA.id,
      brand: 'Yamaha',
      model: 'FZS FI',
      engineCc: 149,
      mfgYearAd: 2019,
      plateNumber: 'BA 12 CHA 9981',
      kmRun: 25600,
      ownerCount: 2,
      billBookStatus: 'copy',
      accidentHistory: 'none',
      modifications: 'modified',
      modificationNotes: 'Aftermarket exhaust',
      colour: 'Matte Grey',
      urgency: 'now',
      windowSeconds: 300,
      status: 'closed',
      openedAt: new Date(now - 20 * 60 * 1000),
      closesAt: new Date(now - 15 * 60 * 1000),
      closedAt: new Date(now - 15 * 60 * 1000),
      photos: {
        create: PHOTO_TYPES.map((t) =>
          photo(`yamaha-fzs-${t}`, t),
        ),
      },
    },
  });
  await prisma.quote.create({
    data: {
      requestId: closedRequest.id,
      valuerUserId: userB.id,
      amountNpr: 195000,
      note: 'Fair condition, exhaust note is a bit loud for resale',
      status: 'submitted',
      respondedInMs: 45000,
    },
  });

  // 4. Fully decided request from Showroom B, with userA's quote as the
  //    winner — so the "closed loop" result view has real data.
  const decidedRequest = await prisma.valuationRequest.create({
    data: {
      showroomId: showroomB.id,
      createdByUserId: userB.id,
      brand: 'Bajaj',
      model: 'Pulsar 150',
      engineCc: 149,
      mfgYearAd: 2018,
      plateNumber: 'LU 5 JA 4410',
      kmRun: 32000,
      ownerCount: 1,
      billBookStatus: 'original',
      accidentHistory: 'none',
      modifications: 'stock',
      colour: 'Red',
      urgency: 'later',
      windowSeconds: 300,
      status: 'decided',
      openedAt: new Date(now - 60 * 60 * 1000),
      closesAt: new Date(now - 55 * 60 * 1000),
      closedAt: new Date(now - 55 * 60 * 1000),
      photos: {
        create: PHOTO_TYPES.map((t) =>
          photo(`bajaj-pulsar-${t}`, t),
        ),
      },
    },
  });
  const winningQuote = await prisma.quote.create({
    data: {
      requestId: decidedRequest.id,
      valuerUserId: userA.id,
      amountNpr: 148000,
      note: 'Good resale demand for this model',
      status: 'submitted',
      respondedInMs: 30000,
    },
  });
  await prisma.decision.create({
    data: {
      requestId: decidedRequest.id,
      winningQuoteId: winningQuote.id,
      offeredToCustomerNpr: 138000,
      marginNpr: 10000,
      outcome: 'exchanged',
      outcomeNotes: 'Customer accepted, exchanged for a used Hornet',
      decidedByUserId: userB.id,
    },
  });

  console.log('Seeded:');
  console.log(`  Showroom A: ${showroomA.name} (owner ${userA.phone}, join code ${showroomA.joinCode})`);
  console.log(`  Showroom B: ${showroomB.name} (owner ${userB.phone}, join code ${showroomB.joinCode})`);
  console.log('  4 valuation requests: 2 live, 1 closed, 1 decided.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
