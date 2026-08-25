import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CreateVenueUnavailabilityDto } from './dto/create-venue-unavailability.dto';
import { CreateVenueDto } from './dto/create-venue.dto';
import { UpdateVenueDto } from './dto/update-venue.dto';
import { VenuesService } from './venues.service';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('venues')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/venues')
export class VenuesController {
  constructor(private readonly venuesService: VenuesService) {}

  @Post()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Create an org-level venue profile' })
  create(@Param('organizationId', ParseUUIDPipe) organizationId: string, @Body() dto: CreateVenueDto) {
    return this.venuesService.create(organizationId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List org-level venues' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.venuesService.findAll(organizationId);
  }

  @Get(':venueId')
  @ApiOperation({ summary: 'Get a venue by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('venueId', ParseUUIDPipe) venueId: string,
  ) {
    return this.venuesService.findOne(organizationId, venueId);
  }

  @Patch(':venueId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Update a venue profile' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Body() dto: UpdateVenueDto,
  ) {
    return this.venuesService.update(organizationId, venueId, dto);
  }

  @Delete(':venueId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Delete a venue' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('venueId', ParseUUIDPipe) venueId: string,
  ) {
    return this.venuesService.remove(organizationId, venueId);
  }

  @Get(':venueId/availability')
  @ApiOperation({
    summary:
      'Day-by-day availability calendar for a venue over [from, to] — each day is available/booked/maintenance. ' +
      "\"Booked\" is derived from matches at this venue; \"maintenance\" from explicit unavailability records; " +
      'booked takes precedence if both apply to the same day (see VenuesService.getAvailability).',
  })
  @ApiQuery({ name: 'from', required: true, description: 'ISO date, inclusive' })
  @ApiQuery({ name: 'to', required: true, description: 'ISO date, inclusive' })
  getAvailability(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.venuesService.getAvailability(organizationId, venueId, from, to);
  }

  @Post(':venueId/unavailability')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Mark a venue unavailable on a date (e.g. "Maintenance")' })
  addUnavailability(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Body() dto: CreateVenueUnavailabilityDto,
  ) {
    return this.venuesService.addUnavailability(organizationId, venueId, dto);
  }

  @Get(':venueId/unavailability')
  @ApiOperation({ summary: 'List unavailability records for a venue' })
  listUnavailability(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('venueId', ParseUUIDPipe) venueId: string,
  ) {
    return this.venuesService.listUnavailability(organizationId, venueId);
  }

  @Delete(':venueId/unavailability/:unavailabilityId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Remove an unavailability record' })
  removeUnavailability(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('venueId', ParseUUIDPipe) venueId: string,
    @Param('unavailabilityId', ParseUUIDPipe) unavailabilityId: string,
  ) {
    return this.venuesService.removeUnavailability(organizationId, venueId, unavailabilityId);
  }
}
