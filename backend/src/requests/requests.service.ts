import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, RequestStatus, User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RequestsGateway } from '../realtime/requests.gateway';
import { ShowroomsService } from '../showrooms/showrooms.service';
import { CreateRequestDto } from './dto/create-request.dto';
import { AddPhotoDto } from './dto/add-photo.dto';
import { DecideRequestDto } from './dto/decide-request.dto';
import { formatNpr } from '../common/utils/npr-formatter';
import { countParticipants } from '../live-bidding/live-bid';

const DUPLICATE_WINDOW_MS = 24 * 60 * 60 * 1000;

@Injectable()
export class RequestsService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private gateway: RequestsGateway,
    private showrooms: ShowroomsService,
  ) {}

  async create(userId: string, dto: CreateRequestDto) {
    const showroomId = await this.showrooms.requireShowroomId(userId);

    if (!dto.force) {
      const dupe = await this.prisma.valuationRequest.findFirst({
        where: {
          plateNumber: normalizePlate(dto.plateNumber),
          openedAt: { gte: new Date(Date.now() - DUPLICATE_WINDOW_MS) },
        },
        orderBy: { openedAt: 'desc' },
      });
      if (dupe) {
        throw new ConflictException({
          message: 'This plate was posted in the last 24 hours',
          existingRequestId: dupe.id,
        });
      }
    }

    const windowSeconds = dto.windowSeconds ?? 300;
    const closesAt = new Date(Date.now() + windowSeconds * 1000);

    const request = await this.prisma.valuationRequest.create({
      data: {
        showroomId,
        createdByUserId: userId,
        brand: dto.brand,
        model: dto.model,
        engineCc: dto.engineCc,
        mfgYearAd: dto.mfgYearAd,
        mfgYearBs: dto.mfgYearBs,
        regYearAd: dto.regYearAd,
        regYearBs: dto.regYearBs,
        plateNumber: normalizePlate(dto.plateNumber),
        regZone: dto.regZone,
        kmRun: dto.kmRun,
        ownerCount: dto.ownerCount,
        billBookStatus: dto.billBookStatus as any,
        taxClearedUntilBs: dto.taxClearedUntilBs,
        insuranceValidUntil: dto.insuranceValidUntil ? new Date(dto.insuranceValidUntil) : null,
        accidentHistory: dto.accidentHistory as any,
        accidentNotes: dto.accidentNotes,
        modifications: dto.modifications as any,
        modificationNotes: dto.modificationNotes,
        colour: dto.colour,
        conditionNotes: dto.conditionNotes,
        maintenanceNotes: dto.maintenanceNotes,
        customerAskingPrice: dto.customerAskingPrice,
        targetBikeDescription: dto.targetBikeDescription,
        targetBikePrice: dto.targetBikePrice,
        customerTopup: dto.customerTopup,
        urgency: dto.urgency as any,
        windowSeconds,
        closesAt,
        photos: dto.photos?.length
          ? { create: dto.photos.map((p) => ({ type: p.type as any, url: p.url, thumbUrl: p.thumbUrl, bytes: p.bytes })) }
          : undefined,
        audio: dto.audio ? { create: { url: dto.audio.url, durationMs: dto.audio.durationMs } } : undefined,
      },
      include: { photos: true, audio: true },
    });

    await this.broadcast(request.id);
    return request;
  }

  /** Draft-only — once a request is broadcast, valuers have already seen
   * its details, so editing would break the blind-bidding fairness. */
  async update(requestId: string, posterUser: User, dto: CreateRequestDto) {
    const request = await this.prisma.valuationRequest.findUniqueOrThrow({ where: { id: requestId } });
    this.assertIsPoster(request, posterUser);
    if (request.status !== 'draft') throw new BadRequestException('Only draft requests can be edited');

    if (dto.photos) {
      await this.prisma.requestPhoto.deleteMany({ where: { requestId } });
    }

    return this.prisma.valuationRequest.update({
      where: { id: requestId },
      data: {
        brand: dto.brand,
        model: dto.model,
        engineCc: dto.engineCc,
        mfgYearAd: dto.mfgYearAd,
        mfgYearBs: dto.mfgYearBs,
        regYearAd: dto.regYearAd,
        regYearBs: dto.regYearBs,
        plateNumber: normalizePlate(dto.plateNumber),
        regZone: dto.regZone,
        kmRun: dto.kmRun,
        ownerCount: dto.ownerCount,
        billBookStatus: dto.billBookStatus as any,
        taxClearedUntilBs: dto.taxClearedUntilBs,
        insuranceValidUntil: dto.insuranceValidUntil ? new Date(dto.insuranceValidUntil) : null,
        accidentHistory: dto.accidentHistory as any,
        accidentNotes: dto.accidentNotes,
        modifications: dto.modifications as any,
        modificationNotes: dto.modificationNotes,
        colour: dto.colour,
        conditionNotes: dto.conditionNotes,
        maintenanceNotes: dto.maintenanceNotes,
        customerAskingPrice: dto.customerAskingPrice,
        targetBikeDescription: dto.targetBikeDescription,
        targetBikePrice: dto.targetBikePrice,
        customerTopup: dto.customerTopup,
        urgency: dto.urgency as any,
        windowSeconds: dto.windowSeconds ?? request.windowSeconds,
        photos: dto.photos?.length
          ? { create: dto.photos.map((p) => ({ type: p.type as any, url: p.url, thumbUrl: p.thumbUrl, bytes: p.bytes })) }
          : undefined,
      },
      include: { photos: true },
    });
  }

  private async broadcast(requestId: string) {
    const request = await this.prisma.valuationRequest.findUniqueOrThrow({
      where: { id: requestId },
    });

    const valuers = await this.prisma.user.findMany({
      where: {
        roleAssignments: { some: { role: 'valuer' } },
        status: 'active',
        isAvailable: true,
        showroomId: { not: request.showroomId },
      },
      select: { id: true },
    });

    // broadcast() only ever runs right after closesAt is set (create/startValuation/rebroadcast).
    const secondsLeft = Math.round(((request.closesAt?.getTime() ?? Date.now()) - Date.now()) / 1000);
    const body = `${request.brand} ${request.model} · ${request.mfgYearAd} · ${request.kmRun.toLocaleString('en-IN')} km · ${formatCountdown(secondsLeft)} left`;

    await this.notifications.sendToUsers(
      valuers.map((v) => v.id),
      'request.broadcast',
      {
        title: 'New valuation request',
        body,
        data: { requestId: request.id, type: 'request.broadcast' },
      },
      request.id,
    );
  }

  async addPhoto(requestId: string, user: User, dto: AddPhotoDto) {
    const request = await this.getOwnedLiveRequest(requestId, user);
    const photo = await this.prisma.requestPhoto.create({
      data: { requestId: request.id, type: dto.type as any, url: dto.url, thumbUrl: dto.thumbUrl, bytes: dto.bytes },
    });
    this.gateway.emitPhotoAdded(requestId, photo);
    return photo;
  }

  /** Role-aware detail: a valuer never receives quote data here — see business rule #2. */
  async findForRole(requestId: string, user: User) {
    const request = await this.prisma.valuationRequest.findUnique({
      where: { id: requestId },
      include: { photos: true, audio: true, showroom: true },
    });
    if (!request) throw new NotFoundException('Request not found');

    const isPoster = request.showroomId === user.showroomId;
    if (!isPoster) {
      const myQuote = await this.prisma.quote.findUnique({
        where: { requestId_valuerUserId: { requestId, valuerUserId: user.id } },
      });
      return { ...stripShowroom(request), myQuote: myQuote ?? null };
    }

    return this.board(requestId, user);
  }

  async board(requestId: string, posterUser: User) {
    const request = await this.prisma.valuationRequest.findUnique({
      where: { id: requestId },
      include: { photos: true, audio: true, showroom: true },
    });
    if (!request) throw new NotFoundException('Request not found');
    this.assertIsPoster(request, posterUser);
    return this.buildBoardPayload(request);
  }

  /** No authorization check — for internal/system callers (the scheduler) that already know it's safe. */
  private async buildBoardPayload(request: { id: string; showroomId: string; showroom?: unknown }) {
    const requestId = request.id;
    const quotes = await this.prisma.quote.findMany({
      where: { requestId },
      include: {
        valuer: { select: { id: true, name: true, showroom: { select: { name: true } } } },
      },
      orderBy: { updatedAt: 'desc' },
    });

    const submitted = quotes.filter((q) => q.status === 'submitted' && q.amountNpr != null);
    const amounts = submitted.map((q) => q.amountNpr!);
    const stats = {
      count: submitted.length,
      passedCount: quotes.filter((q) => q.status === 'passed').length,
      highest: amounts.length ? Math.max(...amounts) : null,
      lowest: amounts.length ? Math.min(...amounts) : null,
      average: amounts.length ? Math.round(amounts.reduce((a, b) => a + b, 0) / amounts.length) : null,
      median: amounts.length ? median(amounts) : null,
    };

    const totalInvited = await this.prisma.user.count({
      where: {
        roleAssignments: { some: { role: 'valuer' } },
        status: 'active',
        showroomId: { not: request.showroomId },
      },
    });

    // Only set once decide() has run — lets a poster re-open an already
    // decided request and see the real recorded outcome, not a guess.
    const decision = await this.prisma.decision.findUnique({
      where: { requestId },
      include: { winningQuote: { include: { valuer: { select: { id: true, name: true } } } } },
    });

    return {
      ...stripShowroom(request as any),
      serverNow: Date.now(),
      totalInvited,
      stats,
      decision: decision
        ? {
            winningQuoteId: decision.winningQuoteId,
            winningValuerName: decision.winningQuote?.valuer.name ?? null,
            offeredToCustomerNpr: decision.offeredToCustomerNpr,
            marginNpr: decision.marginNpr,
            outcome: decision.outcome,
            outcomeNotes: decision.outcomeNotes,
            decidedAt: decision.decidedAt,
          }
        : null,
      quotes: quotes.map(serializeQuoteForBoard),
    };
  }

  async close(requestId: string, posterUser: User) {
    const request = await this.prisma.valuationRequest.findUniqueOrThrow({
      where: { id: requestId },
      include: { showroom: true },
    });
    this.assertIsPoster(request, posterUser);
    if (request.status !== 'live') throw new BadRequestException('Request is not live');

    // Posters can stop the countdown at any time, even with zero quotes so
    // far — finalizeClose already handles that case by marking the request
    // 'expired' instead of 'closed' rather than requiring a winner to exist.
    return this.finalizeClose(requestId);
  }

  /** Called by both the poster's early-close and the scheduler's auto-close sweep. */
  async finalizeClose(requestId: string) {
    const quoteCount = await this.prisma.quote.count({ where: { requestId, status: 'submitted' } });
    const status: RequestStatus = quoteCount === 0 ? 'expired' : 'closed';

    const request = await this.prisma.valuationRequest.update({
      where: { id: requestId },
      data: { status, closedAt: new Date() },
    });

    const board = await this.buildBoardPayload(request);
    this.gateway.emitClosed(requestId, { status: request.status, stats: board.stats });
    return request;
  }

  async decide(requestId: string, posterUser: User, dto: DecideRequestDto) {
    const request = await this.prisma.valuationRequest.findUniqueOrThrow({
      where: { id: requestId },
      include: { showroom: true },
    });
    this.assertIsPoster(request, posterUser);
    if (request.status !== 'closed' && request.status !== 'expired') {
      throw new BadRequestException('Request must be closed before deciding');
    }

    let winningQuote: Prisma.QuoteGetPayload<{}> | null = null;
    if (dto.quoteId) {
      winningQuote = await this.prisma.quote.findFirst({
        where: { id: dto.quoteId, requestId, status: 'submitted' },
      });
      if (!winningQuote) throw new BadRequestException('Quote not found on this request');
    }

    const margin = (winningQuote?.amountNpr ?? dto.offeredNpr) - dto.offeredNpr;

    const decision = await this.prisma.$transaction(async (tx) => {
      const created = await tx.decision.create({
        data: {
          requestId,
          winningQuoteId: winningQuote?.id,
          offeredToCustomerNpr: dto.offeredNpr,
          marginNpr: margin,
          outcome: dto.outcome as any,
          outcomeNotes: dto.outcomeNotes,
          decidedByUserId: posterUser.id,
        },
      });
      await tx.valuationRequest.update({ where: { id: requestId }, data: { status: 'decided' } });
      return created;
    });

    await this.notifyResult(requestId, winningQuote?.id, dto.offeredNpr, dto.outcome);
    return decision;
  }

  /** Business rule: every valuer who responded learns the outcome — the winner explicitly. */
  private async notifyResult(
    requestId: string,
    winningQuoteId: string | undefined,
    offeredNpr: number,
    outcome: string,
  ) {
    const request = await this.prisma.valuationRequest.findUniqueOrThrow({ where: { id: requestId } });
    const respondedQuotes = await this.prisma.quote.findMany({
      where: { requestId, status: { in: ['submitted', 'passed'] } },
    });

    await Promise.all(
      respondedQuotes.map((q) => {
        const won = q.id === winningQuoteId;
        const body = won
          ? `Your quote won! Customer accepted ${formatNpr(offeredNpr)} on the ${request.brand} ${request.model}.`
          : `${request.brand} ${request.model} closed. Winning amount ${formatNpr(offeredNpr)}, outcome: ${outcome}.`;
        return this.notifications.sendToUser(
          q.valuerUserId,
          won ? 'result.won' : 'result.closed',
          { title: 'Valuation result', body, data: { requestId, won: String(won) } },
          requestId,
        );
      }),
    );
  }

  async rebroadcast(requestId: string, posterUser: User, windowSeconds?: number) {
    const request = await this.prisma.valuationRequest.findUniqueOrThrow({
      where: { id: requestId },
      include: { showroom: true },
    });
    this.assertIsPoster(request, posterUser);
    if (request.status !== 'expired' && request.status !== 'closed') {
      throw new BadRequestException('Only a closed or expired request can be rebroadcast');
    }

    const newWindow = windowSeconds ?? Math.min(request.windowSeconds * 2, 600);
    const updated = await this.prisma.valuationRequest.update({
      where: { id: requestId },
      data: {
        status: 'live',
        closesAt: new Date(Date.now() + newWindow * 1000),
        closedAt: null,
        windowSeconds: newWindow,
        broadcastCount: { increment: 1 },
        escalatedAt: null,
      },
    });
    await this.broadcast(requestId);
    return updated;
  }

  /**
   * Turns a draft (photos/details staged, no countdown running yet — see
   * schema.prisma's RequestStatus.draft) into a live broadcast. This is
   * the only way a draft's countdown starts; bulk-imported inventory sits
   * as a draft until the poster explicitly does this.
   */
  async startValuation(requestId: string, posterUser: User, windowSeconds?: number) {
    const request = await this.prisma.valuationRequest.findUniqueOrThrow({
      where: { id: requestId },
      include: { showroom: true },
    });
    this.assertIsPoster(request, posterUser);
    if (request.status !== 'draft') {
      throw new BadRequestException('Only a draft can be started');
    }

    const window = windowSeconds ?? request.windowSeconds;
    const updated = await this.prisma.valuationRequest.update({
      where: { id: requestId },
      data: {
        status: 'live',
        windowSeconds: window,
        closesAt: new Date(Date.now() + window * 1000),
        openedAt: new Date(),
      },
    });
    await this.broadcast(requestId);
    return updated;
  }

  async listInbox(valuerUserId: string) {
    const me = await this.prisma.user.findUniqueOrThrow({ where: { id: valuerUserId } });
    const requests = await this.prisma.valuationRequest.findMany({
      where: {
        showroomId: { not: me.showroomId ?? '__none__' },
        status: { in: ['live', 'closed', 'decided', 'expired'] },
      },
      orderBy: { openedAt: 'desc' },
      take: 50,
      include: {
        photos: { where: { type: 'front' }, take: 1 },
        quotes: { where: { valuerUserId }, select: { status: true, amountNpr: true } },
      },
    });

    return requests.map((r) => ({
      id: r.id,
      brand: r.brand,
      model: r.model,
      mfgYearAd: r.mfgYearAd,
      kmRun: r.kmRun,
      status: r.status,
      closesAt: r.closesAt,
      serverNow: Date.now(),
      coverPhotoUrl: r.photos[0]?.url ?? null,
      myQuoteStatus: r.quotes[0]?.status ?? null,
    }));
  }

  /**
   * The public vehicle feed — newest vehicles from every showroom.
   *
   * Unlike listInbox this does NOT filter out the caller's own showroom.
   * The feed is a browse surface, and a poster who cannot see their own
   * vehicle in it reasonably concludes the posting failed. Bidding on your
   * own showroom's vehicle is still refused by QuotesService (rule #8) and
   * by LiveBiddingService.registerInterest, so visibility costs nothing.
   *
   * Bid amounts are included only for requests already in live mode;
   * blind requests report participation counts but never numbers.
   */
  async listFeed(userId: string, take = 50) {
    const me = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const requests = await this.prisma.valuationRequest.findMany({
      where: { status: { in: ['live', 'closed', 'decided', 'expired'] } },
      orderBy: { openedAt: 'desc' },
      take,
      include: {
        photos: { orderBy: { uploadedAt: 'asc' }, take: 1 },
        showroom: { select: { name: true, district: true } },
        quotes: { select: { valuerUserId: true, status: true, amountNpr: true } },
        interests: { select: { userId: true } },
      },
    });

    return {
      serverNow: Date.now(),
      vehicles: requests.map((r) => {
        const amounts = r.quotes
          .filter((q) => q.status === 'submitted' && q.amountNpr != null)
          .map((q) => q.amountNpr as number);
        const isLive = r.biddingMode === 'live';
        return {
          id: r.id,
          brand: r.brand,
          model: r.model,
          mfgYearAd: r.mfgYearAd,
          kmRun: r.kmRun,
          colour: r.colour,
          engineCc: r.engineCc,
          status: r.status,
          closesAt: r.closesAt,
          coverPhotoUrl: r.photos[0]?.url ?? null,
          showroomName: r.showroom.name,
          showroomDistrict: r.showroom.district,
          isMine: !!me.showroomId && me.showroomId === r.showroomId,
          biddingMode: r.biddingMode,
          participantCount: countParticipants(r.quotes, r.interests),
          bidCount: amounts.length,
          topBidNpr: isLive && amounts.length > 0 ? Math.max(...amounts) : null,
          iHaveBid: r.quotes.some((q) => q.valuerUserId === userId && q.status === 'submitted'),
        };
      }),
    };
  }

  /**
   * Deliberately omits any "best valuator" ranking — that needs quote
   * accuracy (how close a valuer's number lands to the final agreed
   * price), which nothing here tracks yet. Everything below is computed
   * from data we actually have.
   */
  async getDashboard(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (!user.showroomId) {
      return {
        totalBikes: 0,
        draftCount: 0,
        liveCount: 0,
        decidedCount: 0,
        outcomeCounts: {},
        avgQuotesPerValuation: 0,
        quickestSales: [],
      };
    }

    const requests = await this.prisma.valuationRequest.findMany({
      where: { showroomId: user.showroomId },
      include: {
        quotes: { where: { status: 'submitted' }, select: { id: true } },
        decision: { select: { outcome: true, offeredToCustomerNpr: true } },
      },
    });

    const decided = requests.filter((r) => r.status === 'decided' && r.decision);
    const outcomeCounts: Record<string, number> = {};
    for (const r of decided) {
      const outcome = r.decision!.outcome;
      outcomeCounts[outcome] = (outcomeCounts[outcome] ?? 0) + 1;
    }

    const withQuotes = requests.filter((r) => r.quotes.length > 0);
    const avgQuotesPerValuation = withQuotes.length
      ? Math.round((withQuotes.reduce((sum, r) => sum + r.quotes.length, 0) / withQuotes.length) * 10) / 10
      : 0;

    const quickestSales = decided
      .filter((r) => r.decision!.outcome === 'exchanged' && r.closedAt)
      .map((r) => ({
        id: r.id,
        brand: r.brand,
        model: r.model,
        minutesToClose: Math.round((r.closedAt!.getTime() - r.openedAt.getTime()) / 60000),
        offeredNpr: r.decision!.offeredToCustomerNpr,
      }))
      .sort((a, b) => a.minutesToClose - b.minutesToClose)
      .slice(0, 3);

    return {
      totalBikes: requests.length,
      draftCount: requests.filter((r) => r.status === 'draft').length,
      liveCount: requests.filter((r) => r.status === 'live').length,
      decidedCount: decided.length,
      outcomeCounts,
      avgQuotesPerValuation,
      quickestSales,
    };
  }

  async listMine(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (!user.showroomId) return [];

    const requests = await this.prisma.valuationRequest.findMany({
      where: { showroomId: user.showroomId },
      orderBy: { openedAt: 'desc' },
      take: 20,
      include: {
        photos: { where: { type: 'front' }, take: 1 },
        quotes: { where: { status: 'submitted' }, select: { id: true } },
        decision: { select: { offeredToCustomerNpr: true, outcome: true } },
      },
    });

    return requests.map((r) => ({
      id: r.id,
      brand: r.brand,
      model: r.model,
      mfgYearAd: r.mfgYearAd,
      status: r.status,
      closesAt: r.closesAt,
      serverNow: Date.now(),
      coverPhotoUrl: r.photos[0]?.url ?? null,
      quoteCount: r.quotes.length,
      decision: r.decision,
    }));
  }

  /** "The posting showroom" means any member of that showroom, not just whoever hit submit. */
  private assertIsPoster(request: { showroomId: string }, user: User) {
    if (request.showroomId !== user.showroomId) {
      throw new ForbiddenException('Only the posting showroom can do this');
    }
  }

  private async getOwnedLiveRequest(requestId: string, user: User) {
    const request = await this.prisma.valuationRequest.findUnique({
      where: { id: requestId },
      include: { showroom: true },
    });
    if (!request) throw new NotFoundException('Request not found');
    this.assertIsPoster(request, user);
    if (request.status !== 'live') throw new BadRequestException('Request is no longer live');
    return request;
  }
}

function normalizePlate(plate: string): string {
  return plate.trim().toUpperCase().replace(/\s+/g, ' ');
}

function stripShowroom<T extends { showroom?: unknown }>(request: T): Omit<T, 'showroom'> {
  const { showroom: _showroom, ...rest } = request;
  return rest;
}

function serializeQuoteForBoard(q: {
  id: string;
  amountNpr: number | null;
  note: string | null;
  status: string;
  passReason: string | null;
  respondedInMs: number | null;
  updatedAt: Date;
  valuer: { id: string; name: string | null; showroom: { name: string } | null };
}) {
  return {
    id: q.id,
    valuerId: q.valuer.id,
    valuerName: q.valuer.name ?? 'Unnamed valuer',
    showroomName: q.valuer.showroom?.name ?? null,
    amountNpr: q.amountNpr,
    note: q.note,
    status: q.status,
    passReason: q.passReason,
    respondedInMs: q.respondedInMs,
    updatedAt: q.updatedAt,
  };
}

function median(nums: number[]): number {
  const sorted = [...nums].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? Math.round((sorted[mid - 1] + sorted[mid]) / 2) : sorted[mid];
}

function formatCountdown(secondsLeft: number): string {
  const s = Math.max(0, secondsLeft);
  const m = Math.floor(s / 60);
  const rem = s % 60;
  return `${m}:${rem.toString().padStart(2, '0')}`;
}
