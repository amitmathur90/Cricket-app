import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { PostType } from '../../../database/entities/post.entity';

export class CreatePostDto {
  @ApiProperty({ example: 'Finals Weekend Preview' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  title: string;

  @ApiProperty({ example: "Everything you need to know ahead of Sunday's final..." })
  @IsString()
  @IsNotEmpty()
  body: string;

  @ApiPropertyOptional({ enum: PostType, default: PostType.NEWS })
  @IsOptional()
  @IsEnum(PostType)
  type?: PostType;

  @ApiPropertyOptional({
    description: 'Scopes the post to one tournament; omit (or send null) for an org-wide post',
  })
  @IsOptional()
  @IsUUID()
  tournamentId?: string | null;

  @ApiPropertyOptional({ description: 'URL of the uploaded post image (see POST .../uploads)' })
  @IsOptional()
  @IsString()
  @MaxLength(512)
  imageUrl?: string;

  @ApiPropertyOptional({
    description: 'External video link (e.g. YouTube) — this module never hosts video files',
  })
  @IsOptional()
  @IsString()
  @MaxLength(512)
  videoUrl?: string;

  @ApiPropertyOptional({
    description:
      'ISO date/time to publish at (may be past, present, or future). Omit to save as a draft ' +
      '(never visible on the public endpoints).',
  })
  @IsOptional()
  @IsDateString()
  publishedAt?: string;
}
