/**
 * Seeds 10 real bikes pulled from hamroauto.com.np's public inventory API
 * as valuation requests posted by a new "G&G AUTO Enterprises" showroom,
 * owned by chandan@gmail.com — so logging in with that email shows real
 * inventory + real photos instead of synthetic test data.
 *
 * Mileage isn't published on the source site (every listing shows "Not
 * specified"), so it's estimated from the bike's age — flagged in each
 * request's condition notes so it's never mistaken for a real odometer
 * reading.
 *
 * Run with: npx ts-node prisma/seed-hamroauto.ts
 */
import { PhotoType, PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const PHOTO_TYPES: PhotoType[] = ['front', 'left', 'right', 'rear', 'odometer', 'billbook'];

function estimateKm(year: number): number {
  const age = Math.max(0, 2026 - year);
  return Math.min(80000, Math.max(1500, age * 4200));
}

function ownerCountFrom(text: string): number {
  const match = text.match(/(\d+)/);
  if (!match) return 1;
  return Math.min(4, parseInt(match[1], 10));
}

const BIKES = [
  {
    id: '26a4d652-d97d-4d67-95d0-e1525b7b30d7',
    brand: 'Honda', model: 'Dio', mfgYearAd: 2012, engineCc: 110, colour: 'White',
    plateNumber: '58/688', ownership: '1st owner', price: 95000,
    photoIds: ['cb36d9ef-9598-4e90-8f6d-6d02753e4cd6'],
  },
  {
    id: '4a94f9c0-753c-4b9d-b11e-14f96fcbe010',
    brand: 'Other', model: 'Vespa', mfgYearAd: 2021, engineCc: 125, colour: 'Sky blue',
    plateNumber: '025/6583', ownership: '3rd owner', price: 145000,
    photoIds: [
      'cccae9ad-0154-4449-aacf-1cc080a490ca', '2b323ebe-d7e8-4b7d-840f-04ef1d415db7',
      '0c636660-fc51-4042-aacc-f46955a39c3a', '8dc0cacd-8c69-49ed-9261-15b5ed8edc7b',
      'f390579b-3ecf-4c56-8960-f4b06a1d5f2c', '96bf434d-934c-4e41-a5fa-fa7ff02304cf',
    ],
  },
  {
    id: '60b14762-1a2b-45bc-bf26-3f0e2756a51e',
    brand: 'Honda', model: 'BS6 Dio', mfgYearAd: 2025, engineCc: 125, colour: 'Red/Black',
    plateNumber: '061/0962', ownership: 'New vehicle', price: 270000,
    photoIds: ['7c0293b0-c76f-4c2e-8aed-0e4c09b7e563'],
  },
  {
    id: '6c688742-04ff-472d-ac3b-bfdbb1ce24b9',
    brand: 'TVS', model: 'Ntorq', mfgYearAd: 2022, engineCc: 125, colour: 'Red & Black',
    plateNumber: '040/2155', ownership: '2nd owner', price: 210000,
    photoIds: [
      '22837619-0ffc-417b-b4c9-99df47799238', '010b37af-9b1a-4c8d-a1c9-b469a924dde9',
      '8420cdc5-ceef-4a1c-af09-8709a0d1ca5a', 'b8e7b603-6d99-46cb-b7dc-dd38ddb4e536',
      '0b33ec8b-0734-4ba3-832f-0fbe93efdee3',
    ],
  },
  {
    id: '45586b81-95b7-4b5b-9c3e-683ea72eab80',
    brand: 'Suzuki', model: 'Burgman', mfgYearAd: 2021, engineCc: 125, colour: 'Black',
    plateNumber: '028/8493', ownership: '4th+ owner', price: 148000,
    photoIds: ['02a6e70f-1336-4f0e-a669-df572e4f4b39'],
  },
  {
    id: '30e67c72-b87a-456a-a519-d9d14bdb90cd',
    brand: 'Bajaj', model: '200NS', mfgYearAd: 2025, engineCc: 200, colour: 'Red grey',
    plateNumber: '053/9644', ownership: '1st owner', price: 355000,
    photoIds: [
      'fe5b613c-bcf0-47fb-8c60-ad82caf32755', '47228cc3-4564-4b90-aa5c-1a7ab6ee504d',
      'a602cef5-ab9d-47c9-a849-5a4cddb7baec', '98aeaca8-eaa1-47c6-a3ff-115295ff8781',
      '362979a0-e3e0-41ae-99fc-37e201d89eb5',
    ],
  },
  {
    id: '925d4556-f6b0-4dff-947f-2acdd68bc199',
    brand: 'Hero', model: 'Splendor', mfgYearAd: 2007, engineCc: 100, colour: 'Not specified',
    plateNumber: '25/1640', ownership: '3rd owner', price: 40000,
    photoIds: ['518a84db-6d01-4c91-9e67-3b83d175a981'],
  },
  {
    id: '1ae7da2a-6417-4cc4-be92-14c9fd693313',
    brand: 'Bajaj', model: 'Pulsar', mfgYearAd: 2019, engineCc: null, colour: 'Not specified',
    plateNumber: '051/9481', ownership: '3rd owner', price: 110000,
    photoIds: [
      '4249c24b-a6c1-49f2-b0ff-3354f8cbabb0', 'ff7cedcf-0989-42e2-aa9f-d1d649fff22e',
      '0dbdc57e-1d49-4671-b0e7-39a26560c125', '80aeda38-c024-45e5-8173-d0f62aef05fb',
      'b2f04c49-47f7-4e05-8bf8-bbdacbfd4803',
    ],
  },
  {
    id: 'cbec2cc8-e1f0-484a-9ddc-c930c52bcef4',
    brand: 'Yamaha', model: 'Fascino', mfgYearAd: 2017, engineCc: 110, colour: 'Blue',
    plateNumber: '94/70', ownership: '2nd owner', price: 90000,
    photoIds: [
      'f07426b7-a53f-4099-85e2-5238f1682e74', 'ac1d3ffa-adfb-4b78-a8bf-f368d049a82e',
      '0dfa1f34-266c-4b22-8fab-ad0d77defec9', 'a08813d6-8566-4be5-ad65-b1b353a468d3',
    ],
  },
  {
    id: '510d797f-244e-47f5-bf6c-7df42b661188',
    brand: 'Honda', model: 'Grazia', mfgYearAd: 2018, engineCc: null, colour: 'Not specified',
    plateNumber: '96/1718', ownership: '1st owner', price: 135000,
    photoIds: [
      '76c2db69-bd14-488b-adf0-65bc19f7ae8a', 'c12405cd-c1fa-4e24-94da-202052b78edb',
      '4afa1d88-f63d-43d1-83cb-0aa44c264084', 'f12691fe-9008-459c-8952-c0415d2f0eca',
    ],
  },
];

async function main() {
  const email = 'chandan@gmail.com';
  const password = 'HamroAuto2026';

  let user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    user = await prisma.user.create({
      data: {
        email,
        passwordHash: await bcrypt.hash(password, 10),
        name: 'Chandan',
        roleAssignments: { create: [{ role: 'poster' }, { role: 'valuer' }] },
      },
    });
  }

  let showroom = await prisma.showroom.findFirst({ where: { ownerUserId: user.id } });
  if (!showroom) {
    showroom = await prisma.showroom.create({
      data: {
        name: 'G&G AUTO Enterprises',
        district: 'Kathmandu',
        ownerUserId: user.id,
        joinCode: 'HAMROAUTO',
      },
    });
    await prisma.user.update({ where: { id: user.id }, data: { showroomId: showroom.id } });
  }

  let created = 0;

  for (const bike of BIKES) {
    const plateNumber = bike.plateNumber.toUpperCase();
    const existing = await prisma.valuationRequest.findFirst({ where: { plateNumber } });
    if (existing) continue;

    const photoUrls = bike.photoIds.map(
      (pid) => `https://api.hamroauto.com.np/api/public/vehicles/${bike.id}/photos/${pid}`,
    );

    await prisma.valuationRequest.create({
      data: {
        showroomId: showroom.id,
        createdByUserId: user.id,
        brand: bike.brand,
        model: bike.model,
        engineCc: bike.engineCc ?? undefined,
        mfgYearAd: bike.mfgYearAd,
        plateNumber,
        kmRun: estimateKm(bike.mfgYearAd),
        ownerCount: ownerCountFrom(bike.ownership),
        billBookStatus: 'original',
        accidentHistory: 'none',
        modifications: 'stock',
        colour: bike.colour === 'Not specified' ? null : bike.colour,
        conditionNotes:
          'From G&G AUTO Enterprises inventory (hamroauto.com.np) — condition rated 7/10 by their inspection. Kilometers run is estimated from vehicle age; the source listing does not publish an odometer reading.',
        customerAskingPrice: bike.price,
        urgency: 'later',
        windowSeconds: 300,
        // draft: no countdown running — the poster starts each one from
        // Poster Home ("Start Valuation") when they're ready to broadcast it.
        status: 'draft',
        closesAt: null,
        photos: {
          create: photoUrls.map((url, idx) => ({
            type: PHOTO_TYPES[idx % PHOTO_TYPES.length],
            url,
          })),
        },
      },
    });
    created++;
  }

  console.log(`Seeded ${created} real bikes from hamroauto.com.np`);
  console.log(`Showroom: ${showroom.name} (join code ${showroom.joinCode})`);
  console.log(`Login: ${email} / ${password}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
