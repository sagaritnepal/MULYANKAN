import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RequestsGateway } from '../realtime/requests.gateway';
import { RequestsService } from '../requests/requests.service';

const SWEEP_INTERVAL_MS = 5_000;

/**
 * Server-authoritative auto-close and escalation. This is what makes
 * business rule #7 true: a poster whose phone died still finds the
 * request correctly closed, because closing never depends on any client
 * being connected.
 */
@Injectable()
export class RequestsSchedulerService {
  private readonly logger = new Logger('Scheduler');

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private gateway: RequestsGateway,
    private requests: RequestsService,
    private config: ConfigService,
  ) {}

  @Interval(SWEEP_INTERVAL_MS)
  async sweep() {
    await this.escalateNearingClose().catch((e) => this.logger.error('Escalation sweep failed', e));
    await this.autoCloseExpired().catch((e) => this.logger.error('Auto-close sweep failed', e));
    await this.tickLiveRequests().catch((e) => this.logger.error('Tick sweep failed', e));
  }

  private async autoCloseExpired() {
    const due = await this.prisma.valuationRequest.findMany({
      where: { status: 'live', closesAt: { lte: new Date() } },
      select: { id: true },
    });
    for (const { id } of due) {
      await this.requests.finalizeClose(id);
      this.logger.log(`Auto-closed request ${id}`);
    }
  }

  private async escalateNearingClose() {
    const escalationSecondsLeft = Number(this.config.get('ESCALATION_AT_SECONDS_LEFT') ?? 120);
    const minQuotes = Number(this.config.get('ESCALATION_MIN_QUOTES') ?? 3);
    const threshold = new Date(Date.now() + escalationSecondsLeft * 1000);

    const candidates = await this.prisma.valuationRequest.findMany({
      where: { status: 'live', escalatedAt: null, closesAt: { lte: threshold, gt: new Date() } },
      include: { quotes: true },
    });

    for (const request of candidates) {
      const submittedCount = request.quotes.filter((q) => q.status === 'submitted').length;
      if (submittedCount >= minQuotes) continue;

      const respondedUserIds = new Set(request.quotes.map((q) => q.valuerUserId));
      const nonResponders = await this.prisma.user.findMany({
        where: {
          roleAssignments: { some: { role: 'valuer' } },
          status: 'active',
          showroomId: { not: request.showroomId },
          id: { notIn: [...respondedUserIds] },
        },
        select: { id: true },
      });

      const secondsLeft = Math.round(((request.closesAt?.getTime() ?? Date.now()) - Date.now()) / 1000);
      await this.notifications.sendToUsers(
        nonResponders.map((u) => u.id),
        'request.escalated',
        {
          title: 'Only a few minutes left!',
          body: `${request.brand} ${request.model} needs your quote — ${secondsLeft}s left, only ${submittedCount} quotes so far.`,
          data: { requestId: request.id, type: 'request.escalated' },
        },
        request.id,
      );

      await this.prisma.valuationRequest.update({
        where: { id: request.id },
        data: { escalatedAt: new Date() },
      });
      this.gateway.emitEscalated(request.id);
      this.logger.log(`Escalated request ${request.id} to ${nonResponders.length} non-responders`);
    }
  }

  private async tickLiveRequests() {
    const live = await this.prisma.valuationRequest.findMany({
      where: { status: 'live' },
      select: { id: true, closesAt: true },
    });
    for (const r of live) {
      const secondsLeft = Math.max(0, Math.round(((r.closesAt?.getTime() ?? Date.now()) - Date.now()) / 1000));
      this.gateway.emitTick(r.id, secondsLeft);
    }
  }
}
