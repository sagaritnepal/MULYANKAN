import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { User } from '@prisma/client';
import { LiveBiddingService } from './live-bidding.service';
import { PrismaService } from '../prisma/prisma.service';
import { RequestsGateway } from '../realtime/requests.gateway';

/**
 * The blind -> live transition, with Prisma and the gateway mocked. This
 * covers the rules that have no other verification: the participant
 * threshold, the once-only broadcast, and the guards that stop a poster
 * forcing their own vehicle live.
 */
describe('LiveBiddingService.maybeActivate', () => {
  let prisma: {
    valuationRequest: { findUnique: jest.Mock; update: jest.Mock };
    requestInterest: { upsert: jest.Mock };
    quote: { findFirst: jest.Mock; findMany: jest.Mock };
  };
  let gateway: { emitLiveBiddingActivated: jest.Mock };
  let service: LiveBiddingService;

  const request = (over: Record<string, unknown> = {}) => ({
    id: 'r1',
    showroomId: 's1',
    status: 'live',
    biddingMode: 'blind',
    quotes: [],
    interests: [],
    ...over,
  });

  beforeEach(() => {
    prisma = {
      valuationRequest: { findUnique: jest.fn(), update: jest.fn().mockResolvedValue({}) },
      requestInterest: { upsert: jest.fn().mockResolvedValue({}) },
      quote: { findFirst: jest.fn(), findMany: jest.fn().mockResolvedValue([]) },
    };
    gateway = { emitLiveBiddingActivated: jest.fn() };
    service = new LiveBiddingService(
      prisma as unknown as PrismaService,
      gateway as unknown as RequestsGateway,
    );
  });

  it('stays blind below the threshold', async () => {
    prisma.valuationRequest.findUnique.mockResolvedValue(
      request({ interests: [{ userId: 'a' }, { userId: 'b' }] }),
    );
    await expect(service.maybeActivate('r1')).resolves.toBe('blind');
    expect(prisma.valuationRequest.update).not.toHaveBeenCalled();
    expect(gateway.emitLiveBiddingActivated).not.toHaveBeenCalled();
  });

  it('flips to live at exactly three participants and broadcasts once', async () => {
    prisma.valuationRequest.findUnique.mockResolvedValue(
      request({ interests: [{ userId: 'a' }, { userId: 'b' }, { userId: 'c' }] }),
    );
    await expect(service.maybeActivate('r1')).resolves.toBe('live');
    expect(prisma.valuationRequest.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'r1' },
        data: expect.objectContaining({ biddingMode: 'live' }),
      }),
    );
    expect(gateway.emitLiveBiddingActivated).toHaveBeenCalledTimes(1);
    expect(gateway.emitLiveBiddingActivated).toHaveBeenCalledWith('r1', 3);
  });

  it('is idempotent: an already-live request does not re-broadcast', async () => {
    prisma.valuationRequest.findUnique.mockResolvedValue(
      request({
        biddingMode: 'live',
        interests: [{ userId: 'a' }, { userId: 'b' }, { userId: 'c' }],
      }),
    );
    await expect(service.maybeActivate('r1')).resolves.toBe('live');
    expect(prisma.valuationRequest.update).not.toHaveBeenCalled();
    expect(gateway.emitLiveBiddingActivated).not.toHaveBeenCalled();
  });

  it('will not open bidding on a window that has already closed', async () => {
    prisma.valuationRequest.findUnique.mockResolvedValue(
      request({
        status: 'closed',
        interests: [{ userId: 'a' }, { userId: 'b' }, { userId: 'c' }],
      }),
    );
    await expect(service.maybeActivate('r1')).resolves.toBe('blind');
    expect(gateway.emitLiveBiddingActivated).not.toHaveBeenCalled();
  });

  it('does not count passed quotes toward the threshold', async () => {
    prisma.valuationRequest.findUnique.mockResolvedValue(
      request({
        quotes: [
          { valuerUserId: 'a', status: 'passed' },
          { valuerUserId: 'b', status: 'passed' },
          { valuerUserId: 'c', status: 'submitted' },
        ],
      }),
    );
    await expect(service.maybeActivate('r1')).resolves.toBe('blind');
  });

  it('returns blind for a request that does not exist', async () => {
    prisma.valuationRequest.findUnique.mockResolvedValue(null);
    await expect(service.maybeActivate('nope')).resolves.toBe('blind');
  });

  describe('registerInterest', () => {
    const user = (over: Partial<User> = {}) =>
      ({ id: 'u1', showroomId: 's2', ...over }) as User;

    it('refuses interest in your own showroom vehicle', async () => {
      prisma.valuationRequest.findUnique.mockResolvedValue({ id: 'r1', showroomId: 's1' });
      await expect(
        service.registerInterest('r1', user({ showroomId: 's1' })),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma.requestInterest.upsert).not.toHaveBeenCalled();
    });

    it('throws for a missing request', async () => {
      prisma.valuationRequest.findUnique.mockResolvedValue(null);
      await expect(service.registerInterest('r1', user())).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('upserts so tapping Interested twice is not an error', async () => {
      prisma.valuationRequest.findUnique
        .mockResolvedValueOnce({ id: 'r1', showroomId: 's1' })
        .mockResolvedValueOnce(request({ interests: [{ userId: 'u1' }] }));
      const out = await service.registerInterest('r1', user());
      expect(prisma.requestInterest.upsert).toHaveBeenCalledWith(
        expect.objectContaining({ update: {} }),
      );
      expect(out).toEqual({ requestId: 'r1', interested: true, biddingMode: 'blind' });
    });
  });

  describe('highestBid', () => {
    it('returns null when nobody has bid', async () => {
      prisma.quote.findFirst.mockResolvedValue(null);
      await expect(service.highestBid('r1')).resolves.toBeNull();
    });

    it('returns the top submitted amount', async () => {
      prisma.quote.findFirst.mockResolvedValue({ amountNpr: 512000 });
      await expect(service.highestBid('r1')).resolves.toBe(512000);
    });
  });
});
