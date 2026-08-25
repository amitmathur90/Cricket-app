import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Coach } from '../../database/entities/coach.entity';
import { CreateCoachDto } from './dto/create-coach.dto';
import { UpdateCoachDto } from './dto/update-coach.dto';

@Injectable()
export class CoachesService {
  constructor(@InjectRepository(Coach) private readonly coachRepo: Repository<Coach>) {}

  async create(organizationId: string, dto: CreateCoachDto): Promise<Coach> {
    return this.coachRepo.save(this.coachRepo.create({ ...dto, organizationId }));
  }

  async findAll(organizationId: string): Promise<Coach[]> {
    return findManyOrgScoped(this.coachRepo, organizationId);
  }

  async findOne(organizationId: string, coachId: string): Promise<Coach> {
    const coach = await findOneOrgScoped(this.coachRepo, organizationId, { id: coachId });
    if (!coach) {
      throw new NotFoundException('Coach not found');
    }
    return coach;
  }

  async update(organizationId: string, coachId: string, dto: UpdateCoachDto): Promise<Coach> {
    const coach = await this.findOne(organizationId, coachId);
    Object.assign(coach, dto);
    return this.coachRepo.save(coach);
  }

  async remove(organizationId: string, coachId: string): Promise<void> {
    const coach = await this.findOne(organizationId, coachId);
    await this.coachRepo.remove(coach);
  }
}
