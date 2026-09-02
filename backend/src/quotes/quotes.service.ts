import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RequestsGateway } from '../realtime/requests.gateway';
import { SubmitQuoteDto } from './dto/submit-quote.dto';
import { PassQuoteDto } from './dto/pass-quote.dto';

@Injectable()
export class QuotesService {
  constructor(
    private prisma: PrismaService,
    private gateway: RequestsGateway,
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
    // Business rule #8: cannot quote on your own showroom's request.
    if (valuer.showroomId && valuer.showroomId === request.showroomId) {
      throw new ForbiddenException('You cannot quote on your own showroom\'s request');
    }

    const existing = await this.prisma.quote.findUnique({
      where: { requestId_valuerUserId: { requestId, valuerUserId } },
    });

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

    return { id: quote.id, status: quote.status };
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
