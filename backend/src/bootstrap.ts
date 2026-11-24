import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { RejectNullBodyPipe } from './common/input';
import { completeContract } from './common/api-contract';
import { Configuration } from './config/environment';
import { ApiExceptionFilter, EnvelopeInterceptor } from './common/http';
export function configureApp(app: INestApplication, config: Configuration) {
  app.setGlobalPrefix('api');
  app.use(helmet());
  app.enableCors({
    origin: config.origins,
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });
  app.useGlobalPipes(
    new RejectNullBodyPipe(),
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      forbidUnknownValues: true,
    }),
  );
  app.useGlobalFilters(new ApiExceptionFilter());
  app.useGlobalInterceptors(new EnvelopeInterceptor());
}
export function createOpenApi(app: INestApplication) {
  return completeContract(
    SwaggerModule.createDocument(
      app,
      new DocumentBuilder()
        .setTitle('EST Clubs & Events API')
        .setDescription(
          'See API.md for response envelopes, visibility, event eligibility and retry semantics.',
        )
        .setVersion('1.0.0')
        .addBearerAuth()
        .build(),
    ),
  );
}
