import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../../common/decorators/roles.decorator';
import { OrgRole } from '../../common/enums/org-role.enum';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { OrgScopeGuard } from '../../common/guards/org-scope.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { CoachesService } from './coaches.service';
import { CreateCoachDto } from './dto/create-coach.dto';
import { UpdateCoachDto } from './dto/update-coach.dto';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('coaches')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/coaches')
export class CoachesController {
  constructor(private readonly coachesService: CoachesService) {}

  @Post()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Create an org-level coach profile' })
  create(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Body() dto: CreateCoachDto,
  ) {
    return this.coachesService.create(organizationId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List org-level coaches' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.coachesService.findAll(organizationId);
  }

  @Get(':coachId')
  @ApiOperation({ summary: 'Get a coach by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('coachId', ParseUUIDPipe) coachId: string,
  ) {
    return this.coachesService.findOne(organizationId, coachId);
  }

  @Patch(':coachId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Update a coach profile' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('coachId', ParseUUIDPipe) coachId: string,
    @Body() dto: UpdateCoachDto,
  ) {
    return this.coachesService.update(organizationId, coachId, dto);
  }

  @Delete(':coachId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Delete a coach' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('coachId', ParseUUIDPipe) coachId: string,
  ) {
    return this.coachesService.remove(organizationId, coachId);
  }
}
