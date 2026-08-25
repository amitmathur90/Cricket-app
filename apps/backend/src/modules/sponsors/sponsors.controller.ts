import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreateSponsorDto } from './dto/create-sponsor.dto';
import { UpdateSponsorDto } from './dto/update-sponsor.dto';
import { SponsorsService } from './sponsors.service';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('sponsors')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/sponsors')
export class SponsorsController {
  constructor(private readonly sponsorsService: SponsorsService) {}

  @Post()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Create an org-level sponsor profile' })
  create(@Param('organizationId', ParseUUIDPipe) organizationId: string, @Body() dto: CreateSponsorDto) {
    return this.sponsorsService.create(organizationId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List org-level sponsors' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.sponsorsService.findAll(organizationId);
  }

  @Get(':sponsorId')
  @ApiOperation({ summary: 'Get a sponsor by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sponsorId', ParseUUIDPipe) sponsorId: string,
  ) {
    return this.sponsorsService.findOne(organizationId, sponsorId);
  }

  @Patch(':sponsorId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Update a sponsor profile (including visibility flags)' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sponsorId', ParseUUIDPipe) sponsorId: string,
    @Body() dto: UpdateSponsorDto,
  ) {
    return this.sponsorsService.update(organizationId, sponsorId, dto);
  }

  @Delete(':sponsorId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Delete a sponsor' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('sponsorId', ParseUUIDPipe) sponsorId: string,
  ) {
    return this.sponsorsService.remove(organizationId, sponsorId);
  }
}
