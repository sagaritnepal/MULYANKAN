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

export function statusRoom(requestId: string) {
  return `status:${requestId}`;
}
export function boardRoom(requestId: string) {
  return `board:${requestId}`;
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

    // "The posting showroom" is any member of that showroom, not just the creator.
    const isPoster = !!user && user.showroomId === request.showroomId;
    if (isPoster) {
      client.join(boardRoom(request.id));
    }

    client.emit('request.snapshot', {
      requestId: request.id,
      status: request.status,
      serverNow: Date.now(),
      closesAt: request.closesAt?.getTime() ?? null,
      canSeeBoard: isPoster,
    });
  }

  emitQuoteCreated(requestId: string, quote: unknown) {
    this.server.to(boardRoom(requestId)).emit('quote.created', quote);
  }

  emitQuoteUpdated(requestId: string, quote: unknown) {
    this.server.to(boardRoom(requestId)).emit('quote.updated', quote);
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
