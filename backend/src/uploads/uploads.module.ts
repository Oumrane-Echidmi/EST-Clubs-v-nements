import {
  Body,
  Controller,
  Get,
  Inject,
  Injectable,
  Module,
  Param,
  Post,
  Query,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiConsumes,
  ApiProperty,
  ApiPropertyOptional,
  ApiTags,
} from '@nestjs/swagger';
import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { randomUUID } from 'crypto';
import { mkdir, writeFile } from 'fs/promises';
import { resolve } from 'path';
import sharp from 'sharp';
import { Response } from 'express';
import { Actor, CurrentUser, Public, ScopeService } from '../common/security';
import { ApiError } from '../common/http';
import { CONFIG, Configuration } from '../config/environment';
export class UploadQuery {
  @ApiProperty({ enum: ['poster', 'logo', 'avatar'] })
  @IsEnum(['poster', 'logo', 'avatar'])
  kind!: 'poster' | 'logo' | 'avatar';
  @ApiPropertyOptional({ description: 'Required for poster/logo uploads' })
  @IsOptional()
  @IsUUID()
  clubId?: string;
}
export abstract class StorageService {
  abstract put(name: string, data: Buffer): Promise<string>;
}
@Injectable()
export class LocalStorageService extends StorageService {
  constructor(@Inject(CONFIG) private config: Configuration) {
    super();
  }
  async put(name: string, data: Buffer) {
    await mkdir(resolve(this.config.uploadDir), { recursive: true });
    await writeFile(resolve(this.config.uploadDir, name), data, { flag: 'wx' });
    return `${this.config.baseUrl}/api/uploads/files/${name}`;
  }
}
@ApiTags('Uploads')
@Controller('uploads')
export class UploadsController {
  constructor(
    private storage: StorageService,
    private scope: ScopeService,
    @Inject(CONFIG) private config: Configuration,
  ) {}
  @ApiBearerAuth()
  @Post('image')
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file'],
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 5 * 1024 * 1024, files: 1, fields: 0 },
    }),
  )
  async image(
    @CurrentUser() actor: Actor,
    @Query() q: UploadQuery,
    @UploadedFile() file: Express.Multer.File,
    @Body() _body: object,
  ) {
    if (q.kind !== 'avatar') {
      if (!q.clubId)
        throw new ApiError(
          'VALIDATION_ERROR',
          'clubId required for poster/logo uploads',
        );
      await this.scope.assertClub(actor, q.clubId);
    }
    if (
      !file ||
      !['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)
    )
      throw new ApiError(
        'VALIDATION_ERROR',
        'Upload a JPEG, PNG or WebP image',
      );
    const b = file.buffer;
    const format = b.subarray(0, 3).equals(Buffer.from([255, 216, 255]))
      ? 'jpeg'
      : b.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))
        ? 'png'
        : b.toString('ascii', 0, 4) === 'RIFF' &&
            b.toString('ascii', 8, 12) === 'WEBP'
          ? 'webp'
          : null;
    if (!format || file.mimetype !== `image/${format}`)
      throw new ApiError(
        'VALIDATION_ERROR',
        'Image content does not match MIME type',
      );
    let output: Buffer;
    try {
      output = await sharp(b, { limitInputPixels: 25000000, animated: false })
        .rotate()
        .webp({ quality: 85 })
        .toBuffer();
    } catch {
      throw new ApiError(
        'VALIDATION_ERROR',
        'Invalid or excessively large image',
      );
    }
    const url = await this.storage.put(`${randomUUID()}.webp`, output);
    return { url, mimeType: 'image/webp', size: output.length };
  }
  @Public() @Get('files/:filename') imageFile(
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.webp$/.test(
        filename,
      )
    )
      throw new ApiError('NOT_FOUND', 'Image not found', 404);
    res.setHeader('Content-Type', 'image/webp');
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.sendFile(
      filename,
      { root: resolve(this.config.uploadDir), dotfiles: 'deny' },
      (err) => {
        if (err && !res.headersSent)
          res
            .status(404)
            .json({ error: { code: 'NOT_FOUND', message: 'Image not found' } });
      },
    );
  }
}
@Module({
  controllers: [UploadsController],
  providers: [{ provide: StorageService, useClass: LocalStorageService }],
})
export class UploadsModule {}
