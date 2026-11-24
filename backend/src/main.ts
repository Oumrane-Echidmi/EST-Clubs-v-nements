import 'reflect-metadata';
import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { CONFIG, Configuration } from './config/environment';
import { configureApp, createOpenApi } from './bootstrap';
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get<Configuration>(CONFIG);
  configureApp(app, config);
  SwaggerModule.setup('api/docs', app, createOpenApi(app), {
    jsonDocumentUrl: 'api/docs/openapi.json',
  });
  app.enableShutdownHooks();
  await app.listen(config.port, '0.0.0.0');
}
void bootstrap();
