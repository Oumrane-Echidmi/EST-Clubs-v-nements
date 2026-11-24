import { Inject, Injectable, Logger } from '@nestjs/common';
import nodemailer from 'nodemailer';
import { CONFIG, Configuration } from '../config/environment';
export abstract class MailService {
  abstract sendReset(email: string, token: string): Promise<void>;
}
@Injectable()
export class ConfiguredMailService extends MailService {
  private logger = new Logger(ConfiguredMailService.name);
  constructor(@Inject(CONFIG) private config: Configuration) {
    super();
  }
  async sendReset(email: string, token: string) {
    const link = new URL(this.config.resetUrl);
    link.searchParams.set('token', token);
    if (this.config.mailTransport === 'smtp') {
      await nodemailer.createTransport(this.config.smtpUrl!).sendMail({
        from: this.config.mailFrom,
        to: email,
        subject: 'Reset your EST password',
        text: `Reset your password: ${link.toString()}`,
      });
    } else {
      // Development only. Explicit console transport intentionally prints the recovery link.
      this.logger.log(`Development password reset: ${link.toString()}`);
    }
  }
}
