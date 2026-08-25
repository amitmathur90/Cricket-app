import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Sponsor } from '../../database/entities/sponsor.entity';
import { CreateSponsorDto } from './dto/create-sponsor.dto';
import { UpdateSponsorDto } from './dto/update-sponsor.dto';

@Injectable()
export class SponsorsService {
  constructor(@InjectRepository(Sponsor) private readonly sponsorRepo: Repository<Sponsor>) {}

  async create(organizationId: string, dto: CreateSponsorDto): Promise<Sponsor> {
    return this.sponsorRepo.save(this.sponsorRepo.create({ ...dto, organizationId }));
  }

  async findAll(organizationId: string): Promise<Sponsor[]> {
    return findManyOrgScoped(this.sponsorRepo, organizationId);
  }

  async findOne(organizationId: string, sponsorId: string): Promise<Sponsor> {
    const sponsor = await findOneOrgScoped(this.sponsorRepo, organizationId, { id: sponsorId });
    if (!sponsor) {
      throw new NotFoundException('Sponsor not found');
    }
    return sponsor;
  }

  async update(organizationId: string, sponsorId: string, dto: UpdateSponsorDto): Promise<Sponsor> {
    const sponsor = await this.findOne(organizationId, sponsorId);
    Object.assign(sponsor, dto);
    return this.sponsorRepo.save(sponsor);
  }

  async remove(organizationId: string, sponsorId: string): Promise<void> {
    const sponsor = await this.findOne(organizationId, sponsorId);
    await this.sponsorRepo.remove(sponsor);
  }
}
