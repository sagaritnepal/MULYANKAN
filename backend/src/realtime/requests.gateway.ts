import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';
import { isSeller } from '../common/request-ownership';

export function statusRoom(requestId: string) {
  return `status:${requestId}`;
}
export function boardRoom(requestId: string) {
  return `board:${requestId}`;
}
/**
 * The open bid room, used only by requests whose biddingMode is `live`.
 * Distinct from boardRoom because the audiences differ: the board is the
 * poster's private view of sealed quotes, while this is every participant
 * watching an open auction.
 */
export function liveRoom(requestId: string) {
  return `live:${requestId}`;
}

/**
 * Auth happens per-message (client sends its access token with `join`)
 * rather than at the socket handshake, so a token that expires mid-session
 * fails the next join/action instead of silently trusting a stale connection.
 *
 * Blind-bidding enforcement lives here too, not only in the REST API:
 * a valuer can only ever join the status room (countdown + closed event).
 * Quote amounts are only ever emitted into the board room, and joining that
 * room requires being the request's poster (checked against the DB, not
 * trusted from the client).
 *
 * The one exception is a request that has flipped to `live` bidding: its
 * amounts are open by design, so participants are also placed in
 * liveRoom() and receive `bid.placed`. Whether a request is live is read
 * from the DB on join, never taken from the client.
 */
@Injectable()
@WebSocketGateway({ namespace: 'requests', cors: { origin: '*' } })
export class RequestsGateway {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger('RequestsGateway');

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
    private prisma: PrismaService,
  ) {}

  @SubscribeMessage('join')
  async onJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { requestId: string; token: string },
  ) {
    const userId = await this.verify(body.token);
    if (!userId) return client.emit('error', { message: 'Invalid token' });

    const [request, user] = await Promise.all([
      this.prisma.valuationRequest.findUnique({ where: { id: body.requestId } }),
      this.prisma.user.findUnique({ where: { id: userId } }),
    ]);
    if (!request) return client.emit('error', { message: 'Request not found' });

    client.join(statusRoom(request.id));

    // For a showroom's own post this is any member of that showroom, not
    // just the creator; for a public post it is the one person who posted
    // it. Getting this wrong would put every customer in the private board
    // room of every public request — see common/request-ownership.ts.
    const isPoster = !!user && isSeller(request, user);
    if (isPoster) {
      client.join(boardRoom(request.id));
    }

    // Open bidding: everyone watching a live request sees the amounts,
    // the posting showroom included (it already saw them via boardRoom).
    const isLive = request.biddingMode === 'live';
    if (isLive) {
      client.join(liveRoom(request.id));
    }

    client.emit('request.snapshot', {
      requestId: request.id,
      status: request.status,
      serverNow: Date.now(),
      closesAt: request.closesAt?.getTime() ?? null,
      canSeeBoard: isPoster,
      biddingMode: request.biddingMode,
      liveActivatedAt: request.liveActivatedAt?.getTime() ?? null,
    });
  }

  emitQuoteCreated(requestId: string, quote: unknown) {
    this.server.to(boardRoom(requestId)).emit('quote.created', quote);
  }

  emitQuoteUpdated(requestId: string, quote: unknown) {
    this.server.to(boardRoom(requestId)).emit('quote.updated', quote);
  }

  /**
   * Announces the blind -> live flip.
   *
   * Sockets that joined while the request was still blind are not in
   * liveRoom, so they are moved across here rather than being left to
   * reconnect — otherwise the valuer whose bid triggered the flip would
   * sit on a silent screen until they pulled to refresh.
   */
  emitLiveBiddingActivated(requestId: string, participantCount: number) {
    this.server.in(statusRoom(requestId)).socketsJoin(liveRoom(requestId));
    this.server.to(statusRoom(requestId)).emit('bidding.live', {
      requestId,
      participantCount,
      serverNow: Date.now(),
    });
  }

  emitBidPlaced(requestId: string, bid: unknown, topBidNpr: number | null) {
    this.server.to(liveRoom(requestId)).emit('bid.placed', {
      requestId,
      bid,
      topBidNpr,
      serverNow: Date.now(),
    });
  }

  emitClosed(requestId: string, summary: unknown) {
    this.server.to(statusRoom(requestId)).emit('request.closed', summary);
  }

  emitPhotoAdded(requestId: string, photo: unknown) {
    this.server.to(statusRoom(requestId)).emit('photo.added', photo);
  }

  emitEscalated(requestId: string) {
    this.server.to(statusRoom(requestId)).emit('request.escalated', { requestId });
  }

  emitTick(requestId: string, secondsLeft: number) {
    this.server
      .to(statusRoom(requestId))
      .emit('tick', { requestId, serverNow: Date.now(), secondsLeft });
  }

  private async verify(token: string): Promise<string | null> {
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string }>(token, {
        secret: this.config.get('JWT_ACCESS_SECRET'),
      });
      return payload.sub;
    } catch {
      return null;
    }
  }
}
