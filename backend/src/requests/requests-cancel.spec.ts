import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { User } from '@prisma/client';
import { RequestsService } from './requests.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RequestsGateway } from '../realtime/requests.gateway';
import { ShowroomsService } from '../showrooms/showrooms.service';

/**
 * cancel() voids a valuation. It is destructive and poster-only, so the
 * guards get tests even though the happy path is three lines.
 */
describe('RequestsService.cancel', () => {
  let prisma: any;
  let notifications: { sendToUsers: jest.Mock };
  let gateway: { emitClosed: jest.Mock };
  let service: RequestsService;

  const poster = { id: 'u1', showroomId: 's1' } as User;
  const outsider = { id: 'u2', showroomId: 's2' } as User;

  const request = (over: Record<string, unknown> = {}) => ({
    id: 'r1',
    showroomId: 's1',
    brand: 'Honda',
    model: 'CB Shine',
    status: 'live',
    showroom: { id: 's1', name: 'Test Motors' },
    ...over,
  });

  beforeEach(() => {
    prisma = {
      valuationRequest: {
        findUniqueOrThrow: jest.fn(),
        update: jest.fn().mockImplementation(({ data }) => ({ ...request(), ...data })),
      },
      quote: { findMany: jest.fn().mockResolvedValue([]) },
      requestInterest: { findMany: jest.fn().mockResolvedValue([]) },
    };
    notifications = { sendToUsers: jest.fn().mockResolvedValue(undefined) };
    gateway = { emitClosed: jest.fn() };
    service = new RequestsService(
      prisma as unknown as PrismaService,
      notifications as unknown as NotificationsService,
      gateway as unknown as RequestsGateway,
      {} as unknown as ShowroomsService,
    );
  });

  it('cancels a live request and tells the room it is over', async () => {
    prisma.valuationRequest.findUniqueOrThrow.mockResolvedValue(request());
    await expect(service.cancel('r1', poster)).resolves.toEqual({
      id: 'r1',
      status: 'cancelled',
    });
    expect(prisma.valuationRequest.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ status: 'cancelled' }) }),
    );
    expect(gateway.emitClosed).toHaveBeenCalledWith('r1', {
      status: 'cancelled',
      stats: null,
    });
  });

  it('cancels a draft without broadcasting anything — it was never out', async () => {
    prisma.valuationRequest.findUniqueOrThrow.mockResolvedValue(request({ status: 'draft' }));
    await expect(service.cancel('r1', poster)).resolves.toEqual({
      id: 'r1',
      status: 'cancelled',
    });
    expect(gateway.emitClosed).not.toHaveBeenCalled();
    expect(notifications.sendToUsers).not.toHaveBeenCalled();
  });

  it('refuses anyone outside the posting showroom', async () => {
    prisma.valuationRequest.findUniqueOrThrow.mockResolvedValue(request());
    await expect(service.cancel('r1', outsider)).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.valuationRequest.update).not.toHaveBeenCalled();
  });

  it.each(['closed', 'decided', 'expired', 'cancelled'])(
    'refuses to cancel a %s valuation',
    async (status) => {
      prisma.valuationRequest.findUniqueOrThrow.mockResolvedValue(request({ status }));
      await expect(service.cancel('r1', poster)).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.valuationRequest.update).not.toHaveBeenCalled();
    },
  );

  it('notifies everyone who quoted or inquired, each once', async () => {
    prisma.valuationRequest.findUniqueOrThrow.mockResolvedValue(request());
    prisma.quote.findMany.mockResolvedValue([
      { valuerUserId: 'v1' },
      { valuerUserId: 'v2' },
    ]);
    prisma.requestInterest.findMany.mockResolvedValue([{ userId: 'v2' }, { userId: 'v3' }]);

    await service.cancel('r1', poster);

    expect(notifications.sendToUsers).toHaveBeenCalledTimes(1);
    const [userIds, type] = notifications.sendToUsers.mock.calls[0];
    expect(type).toBe('request.cancelled');
    expect([...userIds].sort()).toEqual(['v1', 'v2', 'v3']);
  });

  it('does not send an empty notification when nobody engaged', async () => {
    prisma.valuationRequest.findUniqueOrThrow.mockResolvedValue(request());
    await service.cancel('r1', poster);
    expect(notifications.sendToUsers).not.toHaveBeenCalled();
  });
});
