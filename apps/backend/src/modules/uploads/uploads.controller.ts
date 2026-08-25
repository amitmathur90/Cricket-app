import {
  BadRequestException,
  Controller,
  Param,
  ParseUUIDPipe,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import * as crypto from 'crypto';
import { mkdirSync } from 'fs';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import {
  ALLOWED_UPLOAD_MIME_TYPES,
  MAX_UPLOAD_SIZE_BYTES,
  UPLOADS_DIR,
} from './uploads.constants';

@ApiTags('uploads')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard)
@Controller('organizations/:organizationId/uploads')
export class UploadsController {
  @Post()
  @ApiOperation({ summary: 'Upload an image (player photo / ID document) — returns its served URL' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_UPLOAD_SIZE_BYTES },
      storage: diskStorage({
        destination: (req, _file, callback) => {
          const organizationId = (req.params as { organizationId: string }).organizationId;
          const dest = join(UPLOADS_DIR, organizationId);
          // Directory is created lazily per-org on first upload.
          mkdirSync(dest, { recursive: true });
          callback(null, dest);
        },
        filename: (_req, file, callback) => {
          const unique = crypto.randomUUID();
          callback(null, `${unique}${extname(file.originalname).toLowerCase()}`);
        },
      }),
      fileFilter: (_req, file, callback) => {
        if (!ALLOWED_UPLOAD_MIME_TYPES.includes(file.mimetype)) {
          callback(new BadRequestException('Only JPEG/PNG/WebP/HEIC images are allowed'), false);
          return;
        }
        callback(null, true);
      },
    }),
  )
  upload(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @UploadedFile() file: Express.Multer.File,
  ): { url: string } {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    return { url: `/uploads/${organizationId}/${file.filename}` };
  }
}
