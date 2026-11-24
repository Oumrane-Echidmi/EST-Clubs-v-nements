import 'reflect-metadata';
import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { writeFile, mkdir } from 'fs/promises';
import { resolve } from 'path';
import { AppModule } from '../src/app.module';
import { configureApp, createOpenApi } from '../src/bootstrap';
import { CONFIG, Configuration } from '../src/config/environment';
async function main() {
  const app = await NestFactory.create(AppModule, { logger: false });
  configureApp(app, app.get<Configuration>(CONFIG));
  const document = createOpenApi(app);
  await mkdir(resolve('../docs'), { recursive: true });
  await writeFile(
    resolve('../docs/openapi.json'),
    JSON.stringify(document, null, 2) + '\n',
  );
  await app.close();
}
void main();
