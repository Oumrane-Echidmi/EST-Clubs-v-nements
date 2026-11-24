import { Inject, Injectable, Logger } from '@nestjs/common';
import { initializeApp, cert, App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { CONFIG, Configuration } from '../config/environment';
export abstract class PushService {
  abstract send(
    tokens: string[],
    title: string,
    body: string,
    eventId: string | null,
  ): Promise<void>;
}
@Injectable()
export class NoopPushService extends PushService {
  async send(): Promise<void> {}
}
@Injectable()
export class FcmPushService extends PushService {
  private app: App;
  private logger = new Logger(FcmPushService.name);
  constructor(@Inject(CONFIG) config: Configuration) {
    super();
    this.app = initializeApp(
      { credential: cert(config.firebase!) },
      `est-${process.pid}`,
    );
  }
  async send(
    tokens: string[],
    title: string,
    body: string,
    eventId: string | null,
  ) {
    for (let i = 0; i < tokens.length; i += 500) {
      const result = await getMessaging(this.app).sendEachForMulticast({
        tokens: tokens.slice(i, i + 500),
        notification: { title, body },
        data: eventId ? { eventId } : {},
      });
      if (result.failureCount)
        this.logger.warn(
          `Push delivery failed for ${result.failureCount} devices`,
        );
    }
  }
}
