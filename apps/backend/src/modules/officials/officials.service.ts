import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { FindOptionsWhere, Repository } from 'typeorm';
import { findOneOrgScoped, orgScopedWhere } from '../../common/base/org-scoped.repository';
import { Official, OfficialRole } from '../../database/entities/official.entity';
import { CreateOfficialDto } from './dto/create-official.dto';
import { UpdateOfficialDto } from './dto/update-official.dto';

@Injectable()
export class OfficialsService {
  constructor(@InjectRepository(Official) private readonly officialRepo: Repository<Official>) {}

  async create(organizationId: string, dto: CreateOfficialDto): Promise<Official> {
    return this.officialRepo.save(this.officialRepo.create({ ...dto, organizationId }));
  }

  async findAll(organizationId: string, role?: string): Promise<Official[]> {
    const where: FindOptionsWhere<Official> = {};
    if (role) {
      if (!Object.values(OfficialRole).includes(role as OfficialRole)) {
        throw new BadRequestException(`Invalid role filter: ${role}`);
      }
      where.role = role as OfficialRole;
    }
    return this.officialRepo.find({ where: orgScopedWhere<Official>(organizationId, where) });
  }

  async findOne(organizationId: string, officialId: string): Promise<Official> {
    const official = await findOneOrgScoped(this.officialRepo, organizationId, { id: officialId });
    if (!official) {
      throw new NotFoundException('Official not found');
    }
    return official;
  }

  async update(organizationId: string, officialId: string, dto: UpdateOfficialDto): Promise<Official> {
    const official = await this.findOne(organizationId, officialId);
    Object.assign(official, dto);
    return this.officialRepo.save(official);
  }

  async remove(organizationId: string, officialId: string): Promise<void> {
    const official = await this.findOne(organizationId, officialId);
    await this.officialRepo.remove(official);
  }
}
