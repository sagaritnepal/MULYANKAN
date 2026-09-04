import { ConflictException, ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { User } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RequestsGateway } from '../realtime/requests.gateway';
import { assertCanBid, isSeller, sellerLabel } from '../common/request-ownership';
import {
  LIVE_BIDDING_MIN_PARTICIPANTS,
  countParticipants,
  serializeLiveBid,
} from './live-bid';

/**
 * Owns the blind -> live transition and the open bid board.
 *
 * Lives in its own module rather than inside RequestsService because
 * QuotesService needs it too, and QuotesService -> RequestsService ->
 * (nothing back) is only acyclic by accident; this keeps it that way.
 */
@Injectable()
export class LiveBiddingService {
  private readonly logger = new Logger('LiveBidding');

  constructor(
    private prisma: PrismaService,
    private gateway: RequestsGateway,
    private config: ConfigService,
  ) {}

  /**
   * How many engaged valuers open the board. Env-overridable so a
   * two-person team can exercise live bidding; anything unparseable or
   * below 1 falls back to the product default rather than throwing on
   * every quote.
   */
  get minParticipants(): number {
    const raw = this.config.get<string>('LIVE_BIDDING_MIN_PARTICIPANTS');
    const parsed = raw == null ? Number.NaN : Number.parseInt(String(raw), 10);
    return Number.isFinite(parsed) && parsed >= 1 ? parsed : LIVE_BIDDING_MIN_PARTICIPANTS;
  }

  /**
   * Records an "inquiry" — interest without a number attached — and
   * re-checks the live threshold. Upsert rather than create so tapping
   * Interested twice is a no-op instead of a 500 on the unique index.
   */
  async registerInterest(requestId: string, user: User) {
    const request = await this.prisma.valuationRequest.findUnique({ where: { id: requestId } });
    if (!request) throw new NotFoundException('Request not found');

    // Same rule as quoting: a seller cannot drive bidding on their own
    // vehicle, or they could inflate the participant count and force it
    // live, and a member of the public cannot bid at all.
    assertCanBid(request, user);

    await this.prisma.requestInterest.upsert({
      where: { requestId_userId: { requestId, userId: user.id } },
      create: { requestId, userId: user.id },
      update: {},
    });

    const biddingMode = await this.maybeActivate(requestId);
    return { requestId, interested: true, biddingMode };
  }

  /**
   * Flips a request to live once enough distinct valuers are engaged.
   *
   * Safe to call after every quote and every inquiry: a request already
   * live returns early, so `bidding.live` is broadcast exactly once. Only
   * `live`-status requests are eligible — there is no point opening
   * bidding on a window that has already closed.
   */
  async maybeActivate(requestId: string): Promise<'blind' | 'live'> {
    const request = await this.prisma.valuationRequest.findUnique({
      where: { id: requestId },
      include: {
        quotes: { select: { valuerUserId: true, status: true } },
        interests: { select: { userId: true } },
      },
    });
    if (!request) return 'blind';
    if (request.biddingMode === 'live') return 'live';
    if (request.status !== 'live') return 'blind';

    const participants = countParticipants(request.quotes, request.interests);
    if (participants < this.minParticipants) return 'blind';

    await this.prisma.valuationRequest.update({
      where: { id: requestId },
      data: { biddingMode: 'live', liveActivatedAt: new Date() },
    });
    this.logger.log(
      `Request ${requestId} went live with ${participants} participants (threshold ${this.minParticipants})`,
    );
    this.gateway.emitLiveBiddingActivated(requestId, participants);
    return 'live';
  }

  /**
   * The open bid board, highest first.
   *
   * Throws while the request is still blind instead of returning an empty
   * list, so a client can never render "no bids yet" for a vehicle that
   * actually has sealed bids it isn't allowed to see.
   */
  async board(requestId: string, viewer: User) {
    const request = await this.prisma.valuationRequest.findUnique({
      where: { id: requestId },
      include: {
        quotes: {
          where: { status: 'submitted', amountNpr: { not: null } },
          orderBy: { amountNpr: 'desc' },
          include: { valuer: { select: { id: true, showroom: { select: { name: true } } } } },
        },
        interests: { select: { userId: true } },
        showroom: { select: { name: true } },
        photos: { orderBy: { uploadedAt: 'asc' }, take: 1 },
      },
    });
    if (!request) throw new NotFoundException('Request not found');
    if (request.biddingMode !== 'live') {
      throw new ConflictException('Live bidding has not started on this vehicle yet');
    }

    const allQuotes = await this.prisma.quote.findMany({
      where: { requestId },
      select: { valuerUserId: true, status: true },
    });

    return {
      requestId: request.id,
      brand: request.brand,
      model: request.model,
      mfgYearAd: request.mfgYearAd,
      kmRun: request.kmRun,
      coverPhotoUrl: request.photos[0]?.url ?? null,
      showroomName: sellerLabel(request),
      status: request.status,
      biddingMode: request.biddingMode,
      serverNow: Date.now(),
      closesAt: request.closesAt,
      liveActivatedAt: request.liveActivatedAt,
      isMine: isSeller(request, viewer),
      participantCount: countParticipants(allQuotes, request.interests),
      topBidNpr: request.quotes[0]?.amountNpr ?? null,
      bids: request.quotes.map(serializeLiveBid),
    };
  }

  /** Current highest submitted amount, or null when nobody has bid yet. */
  async highestBid(requestId: string): Promise<number | null> {
    const top = await this.prisma.quote.findFirst({
      where: { requestId, status: 'submitted', amountNpr: { not: null } },
      orderBy: { amountNpr: 'desc' },
      select: { amountNpr: true },
    });
    return top?.amountNpr ?? null;
  }
}
