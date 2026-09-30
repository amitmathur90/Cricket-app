import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { OrgMembership } from '../../database/entities/org-membership.entity';
import { Organization } from '../../database/entities/organization.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { User } from '../../database/entities/user.entity';
import { OrganizationsController } from './organizations.controller';
import { OrganizationsService } from './organizations.service';

@Module({
  imports: [TypeOrmModule.forFeature([Organization, OrgMembership, User, Tournament])],
  controllers: [OrganizationsController],
  providers: [OrganizationsService],
  exports: [OrganizationsService],
})
export class OrganizationsModule {}
