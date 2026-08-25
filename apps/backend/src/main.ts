import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { UPLOADS_DIR } from './modules/uploads/uploads.constants';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const configService = app.get(ConfigService);

  // Serve uploaded player photos/ID documents as static files.
  app.useStaticAssets(UPLOADS_DIR, { prefix: '/uploads/' });

  app.enableCors({
    origin: configService.get<string>('cors.origin') ?? '*',
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  const swaggerConfig = new DocumentBuilder()
    .setTitle('Ammct — Cricket Tournament SaaS API')
    .setDescription(
      'Multi-tenant cricket tournament platform API. M1: auth, organizations, users, tournaments, teams, players.',
    )
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api-docs', app, document, {
    jsonDocumentUrl: 'api-json',
  });

  const port = configService.get<number>('port') ?? 3000;
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Ammct backend listening on http://localhost:${port} (docs: /api-docs)`);
}

bootstrap();
