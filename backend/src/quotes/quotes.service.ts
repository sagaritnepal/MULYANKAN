import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RequestsGateway } from '../realtime/requests.gateway';
import { SubmitQuoteDto } from './dto/submit-quote.dto';
import { PassQuoteDto } from './dto/pass-quote.dto';
import { LiveBiddingService } from '../live-bidding/live-bidding.service';
import { serializeLiveBid } from '../live-bidding/live-bid';
import { formatNpr } from '../common/utils/npr-formatter';
import { assertCanBid } from '../common/request-ownership';

@Injectable()
export class QuotesService {
  constructor(
    private prisma: PrismaService,
    private gateway: RequestsGateway,
    private liveBidding: LiveBiddingService,
  ) {}

  async submit(requestId: string, valuerUserId: string, dto: SubmitQuoteDto) {
    return this.upsert(requestId, valuerUserId, {
      status: 'submitted',
      amountNpr: dto.amountNpr,
      note: dto.note,
      passReason: null,
    });
  }

  async pass(requestId: string, valuerUserId: string, dto: PassQuoteDto) {
    return this.upsert(requestId, valuerUserId, {
      status: 'passed',
      amountNpr: null,
      note: null,
      passReason: dto.reason,
    });
  }

  private async upsert(
    requestId: string,
    valuerUserId: string,
    data: { status: 'submitted' | 'passed'; amountNpr: number | null; note?: string | null; passReason: string | null },
  ) {
    const request = await this.prisma.valuationRequest.findUnique({ where: { id: requestId } });
    if (!request) throw new NotFoundException('Request not found');

    // Business rule #3: enforced here against the server clock, never the client's.
    // A 'live' request always has closesAt set (create()/startValuation() set both
    // together) — the null check is TypeScript bookkeeping, not a real runtime case.
    if (request.status !== 'live' || !request.closesAt || request.closesAt.getTime() <= Date.now()) {
      throw new ConflictException(`Window closed at ${request.closesAt?.toLocaleTimeString() ?? 'an earlier time'}.`);
    }

    const valuer = await this.prisma.user.findUniqueOrThrow({ where: { id: valuerUserId } });
    // Business rule #8, plus the rule that only recondition houses value
    // vehicles at all. Both live in one place now because a public request
    // has no showroom to compare against — see common/request-ownership.ts.
    assertCanBid(request, valuer);

    const existing = await this.prisma.quote.findUnique({
      where: { requestId_valuerUserId: { requestId, valuerUserId } },
    });

    // Once a request is live the sealed-bid rules no longer apply and it
    // behaves as an ascending auction: a visible number can only be beaten
    // by a higher one. Blind mode keeps its original behaviour, where a
    // valuer may revise in either direction because nobody else can see it.
    if (request.biddingMode === 'live' && data.status === 'submitted' && data.amountNpr != null) {
      const highest = await this.liveBidding.highestBid(requestId);
      if (highest != null && data.amountNpr <= highest) {
        throw new ConflictException(
          `Live bidding is open on this vehicle — your bid must beat the current top bid of ${formatNpr(highest)}.`,
        );
      }
    }

    const respondedInMs = existing?.respondedInMs ?? Date.now() - request.openedAt.getTime();

    const quote = await this.prisma.$transaction(async (tx) => {
      const saved = existing
        ? await tx.quote.update({
            where: { id: existing.id },
            data: { ...data, respondedInMs },
          })
        : await tx.quote.create({
            data: { requestId, valuerUserId, ...data, respondedInMs },
          });

      await tx.quoteRevision.create({
        data: { quoteId: saved.id, amountNpr: data.amountNpr, note: data.note ?? null },
      });

      return saved;
    });

    const withValuer = await this.prisma.quote.findUniqueOrThrow({
      where: { id: quote.id },
      include: { valuer: { select: { id: true, name: true, showroom: { select: { name: true } } } } },
    });

    if (existing) {
      this.gateway.emitQuoteUpdated(requestId, serializeQuote(withValuer));
    } else {
      this.gateway.emitQuoteCreated(requestId, serializeQuote(withValuer));
    }

    // Activation first, then the bid broadcast: maybeActivate moves the
    // already-connected sockets into the live room, so a bid that trips
    // the threshold is itself visible to everyone watching.
    const biddingMode = await this.liveBidding.maybeActivate(requestId);
    if (biddingMode === 'live' && data.status === 'submitted' && data.amountNpr != null) {
      this.gateway.emitBidPlaced(
        requestId,
        serializeLiveBid(withValuer),
        await this.liveBidding.highestBid(requestId),
      );
    }

    return { id: quote.id, status: quote.status, biddingMode };
  }
}

function serializeQuote(q: {
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
