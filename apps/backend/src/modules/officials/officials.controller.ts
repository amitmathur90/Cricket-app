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
import { CreateOfficialDto } from './dto/create-official.dto';
import { UpdateOfficialDto } from './dto/update-official.dto';
import { OfficialsService } from './officials.service';

const ADMIN_ROLES = [OrgRole.ORG_ADMIN, OrgRole.TOURNAMENT_ADMIN];

@ApiTags('officials')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, OrgScopeGuard, RolesGuard)
@Controller('organizations/:organizationId/officials')
export class OfficialsController {
  constructor(private readonly officialsService: OfficialsService) {}

  @Post()
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Create an org-level official (umpire/scorer/match referee)' })
  create(@Param('organizationId', ParseUUIDPipe) organizationId: string, @Body() dto: CreateOfficialDto) {
    return this.officialsService.create(organizationId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List org-level officials, optionally filtered by role' })
  @ApiQuery({ name: 'role', required: false, description: 'umpire | scorer | match_referee' })
  findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string, @Query('role') role?: string) {
    return this.officialsService.findAll(organizationId, role);
  }

  @Get(':officialId')
  @ApiOperation({ summary: 'Get an official by id' })
  findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('officialId', ParseUUIDPipe) officialId: string,
  ) {
    return this.officialsService.findOne(organizationId, officialId);
  }

  @Patch(':officialId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Update an official' })
  update(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('officialId', ParseUUIDPipe) officialId: string,
    @Body() dto: UpdateOfficialDto,
  ) {
    return this.officialsService.update(organizationId, officialId, dto);
  }

  @Delete(':officialId')
  @Roles(...ADMIN_ROLES)
  @ApiOperation({ summary: 'Delete an official' })
  remove(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('officialId', ParseUUIDPipe) officialId: string,
  ) {
    return this.officialsService.remove(organizationId, officialId);
  }
}
