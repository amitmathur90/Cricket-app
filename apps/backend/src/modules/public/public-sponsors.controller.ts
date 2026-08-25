import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Sponsor } from '../../database/entities/sponsor.entity';

/**
 * Column-level allow-list — deliberately excludes `amount`,
 * `contractStartDate`/`contractEndDate` (financial/contract terms) and the
 * `visibleOn*` flags themselves (internal display-surface configuration),
 * alongside the standard `organizationId`/`status` housekeeping columns.
 */
const PUBLIC_SPONSOR_SELECT = {
  id: true,
  companyName: true,
  logoUrl: true,
  packageName: true,
} as const;

@ApiTags('public')
@Controller('public/organizations/:organizationId/sponsors')
export class PublicSponsorsController {
  constructor(@InjectRepository(Sponsor) private readonly sponsorRepo: Repository<Sponsor>) {}

  @Get()
  @ApiOperation({
    summary:
      "[Public] Sponsors with visibleOnApp=true only — this is that flag's first real consumer. " +
      'Financial fields (amount, contract dates) are never returned here.',
  })
  async findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.sponsorRepo.find({
      where: { organizationId, visibleOnApp: true },
      select: PUBLIC_SPONSOR_SELECT,
      order: { companyName: 'ASC' },
    });
  }
}
