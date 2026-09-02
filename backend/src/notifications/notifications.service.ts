import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { PrismaService } from '../prisma/prisma.service';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class NotificationsService implements OnModuleInit {
  private readonly logger = new Logger('Push');
  private firebaseReady = false;

  constructor(
    private config: ConfigService,
    private prisma: PrismaService,
  ) {}

  onModuleInit() {
    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const privateKey = this.config.get<string>('FIREBASE_PRIVATE_KEY');
    if (!projectId || !clientEmail || !privateKey) {
      this.logger.warn('FCM not configured — pushes will be logged to console only');
      return;
    }
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey: privateKey.replace(/\\n/g, '\n'),
      }),
    });
    this.firebaseReady = true;
  }

  /** Sends a high-priority push and logs it for the "final result" audit trail. */
  async sendToUser(
    userId: string,
    type: string,
    push: PushPayload,
    requestId?: string,
  ): Promise<void> {
    await this.prisma.notification.create({
      data: { userId, requestId, type, payload: push as any },
    });

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.fcmToken) {
      this.logger.debug(`No FCM token for user ${userId}, skipping push (type=${type})`);
      return;
    }

    if (!this.firebaseReady) {
      this.logger.log(`[DEV PUSH -> ${userId}] ${push.title}: ${push.body}`);
      return;
    }

    try {
      await admin.messaging().send({
        token: user.fcmToken,
        notification: { title: push.title, body: push.body },
        data: push.data ?? {},
        android: {
          priority: 'high',
          notification: { sound: 'default', channelId: 'valuation_requests' },
        },
      });
    } catch (err) {
      this.logger.error(`FCM send failed for user ${userId}: ${(err as Error).message}`);
    }
  }

  async sendToUsers(userIds: string[], type: string, push: PushPayload, requestId?: string) {
    await Promise.all(userIds.map((id) => this.sendToUser(id, type, push, requestId)));
  }
}
