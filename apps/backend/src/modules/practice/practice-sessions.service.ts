import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, FindOptionsWhere, Repository } from 'typeorm';
import { findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Coach } from '../../database/entities/coach.entity';
import { NotificationType } from '../../database/entities/notification.entity';
import {
  PracticeSession,
  PracticeSessionStatus,
} from '../../database/entities/practice-session.entity';
import { Team } from '../../database/entities/team.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { CreatePracticeSessionDto } from './dto/create-practice-session.dto';
import { UpdatePracticeSessionDto } from './dto/update-practice-session.dto';

export interface FindPracticeSessionsFilters {
  status?: string;
  from?: string;
  to?: string;
}

/** Eager-loaded so responses include coach name/specialization, not just coachId. */
const RESPONSE_RELATIONS = ['coach'];

@Injectable()
export class PracticeSessionsService {
  constructor(
    @InjectRepository(PracticeSession)
    private readonly sessionRepo: Repository<PracticeSession>,
    @InjectRepository(Team) private readonly teamRepo: Repository<Team>,
    @InjectRepository(Coach) private readonly coachRepo: Repository<Coach>,
    private readonly notificationsService: NotificationsService,
  ) {}

  /** Verifies the team belongs to the org and returns it, or throws NotFoundException. */
  private async getOrgScopedTeam(organizationId: string, teamId: string): Promise<Team> {
    const team = await findOneOrgScoped(this.teamRepo, organizationId, { id: teamId });
    if (!team) {
      throw new NotFoundException('Team not found');
    }
    return team;
  }

  private parseDate(value: string, field: string): Date {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`Invalid ${field} date`);
    }
    return date;
  }

  /** If a coachId is being set, verifies it belongs to the same organization. */
  private async validateCoach(organizationId: string, coachId: string | null | undefined): Promise<void> {
    if (coachId === undefined || coachId === null) {
      return;
    }
    const coach = await findOneOrgScoped(this.coachRepo, organizationId, { id: coachId });
    if (!coach) {
      throw new BadRequestException('coachId must be a coach belonging to this organization');
    }
  }

  async create(
    organizationId: string,
    teamId: string,
    dto: CreatePracticeSessionDto,
    createdByUserId: string,
  ): Promise<PracticeSession> {
    const team = await this.getOrgScopedTeam(organizationId, teamId);
    await this.validateCoach(organizationId, dto.coachId);

    const session = await this.sessionRepo.save(
      this.sessionRepo.create({
        organizationId,
        teamId,
        coachId: dto.coachId ?? null,
        scheduledAt: this.parseDate(dto.scheduledAt, 'scheduledAt'),
        venueName: dto.venueName ?? null,
        practiceType: dto.practiceType,
        durationMinutes: dto.durationMinutes ?? null,
        notes: dto.notes ?? null,
        createdByUserId,
      }),
    );

    if (team.ownerUserId) {
      await this.notificationsService.notify(organizationId, [team.ownerUserId], {
        type: NotificationType.PRACTICE_REMINDER,
        title: 'Practice session scheduled',
        message: `A practice session (${session.practiceType}) has been scheduled for ${session.scheduledAt.toISOString()}`,
        relatedEntityType: 'practice_session',
        relatedEntityId: session.id,
      });
    }

    return this.findOne(organizationId, teamId, session.id);
  }

  async findAll(
    organizationId: string,
    teamId: string,
    filters: FindPracticeSessionsFilters,
  ): Promise<PracticeSession[]> {
    await this.getOrgScopedTeam(organizationId, teamId);

    const where: FindOptionsWhere<PracticeSession> = { organizationId, teamId };
    if (filters.status) {
      if (!Object.values(PracticeSessionStatus).includes(filters.status as PracticeSessionStatus)) {
        throw new BadRequestException(`Invalid status filter: ${filters.status}`);
      }
      where.status = filters.status as PracticeSessionStatus;
    }
    if (filters.from || filters.to) {
      const from = filters.from ? this.parseDate(filters.from, 'from') : new Date(0);
      const to = filters.to ? this.parseDate(filters.to, 'to') : new Date(8640000000000000);
      where.scheduledAt = Between(from, to);
    }

    return this.sessionRepo.find({
      where,
      relations: RESPONSE_RELATIONS,
      order: { scheduledAt: 'ASC' },
    });
  }

  async findOne(organizationId: string, teamId: string, sessionId: string): Promise<PracticeSession> {
    await this.getOrgScopedTeam(organizationId, teamId);
    const session = await this.sessionRepo.findOne({
      where: { id: sessionId, organizationId, teamId },
      relations: RESPONSE_RELATIONS,
    });
    if (!session) {
      throw new NotFoundException('Practice session not found');
    }
    return session;
  }

  /** Internal helper — bare entity (no relations), for update/remove. */
  private async findOneEntity(
    organizationId: string,
    teamId: string,
    sessionId: string,
  ): Promise<PracticeSession> {
    await this.getOrgScopedTeam(organizationId, teamId);
    const session = await this.sessionRepo.findOne({ where: { id: sessionId, organizationId, teamId } });
    if (!session) {
      throw new NotFoundException('Practice session not found');
    }
    return session;
  }

  /**
   * Single generic PATCH covering every field — reassign coach, change
   * venue/type/duration/notes, reschedule, and status transitions
   * (including `{ status: 'cancelled' }` as an alternative to DELETE).
   */
  async update(
    organizationId: string,
    teamId: string,
    sessionId: string,
    dto: UpdatePracticeSessionDto,
  ): Promise<PracticeSession> {
    const session = await this.findOneEntity(organizationId, teamId, sessionId);
    await this.validateCoach(organizationId, dto.coachId);

    const { scheduledAt, ...rest } = dto;
    Object.assign(session, rest);
    if (scheduledAt !== undefined) {
      session.scheduledAt = this.parseDate(scheduledAt, 'scheduledAt');
    }

    await this.sessionRepo.save(session);
    return this.findOne(organizationId, teamId, sessionId);
  }

  /** Hard delete — practice sessions are lower-stakes than matches, no soft-cancel/hard-delete split. */
  async remove(organizationId: string, teamId: string, sessionId: string): Promise<void> {
    const session = await this.findOneEntity(organizationId, teamId, sessionId);
    await this.sessionRepo.remove(session);
  }
}
