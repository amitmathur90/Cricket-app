import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { NotificationType } from '../../database/entities/notification.entity';
import { Player } from '../../database/entities/player.entity';
import {
  TournamentApplication,
  TournamentApplicationStatus,
} from '../../database/entities/tournament-application.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { PlayersService } from '../players/players.service';
import { CreateTournamentApplicationDto } from './dto/create-tournament-application.dto';
import { ReviewTournamentApplicationDto } from './dto/review-tournament-application.dto';

@Injectable()
export class TournamentApplicationsService {
  constructor(
    @InjectRepository(TournamentApplication)
    private readonly applicationRepo: Repository<TournamentApplication>,
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(Player) private readonly playerRepo: Repository<Player>,
    private readonly playersService: PlayersService,
    private readonly notificationsService: NotificationsService,
  ) {}

  /**
   * Self-service: any authenticated org member (typically a `player`-role
   * user) applies to a specific tournament. Reuses the caller's existing
   * Player profile in this org if one exists (ignoring the submitted
   * profile fields in that case — the existing profile wins); otherwise
   * creates one from the submitted fields via PlayersService.create,
   * linking it to the caller's userId.
   */
  async apply(
    organizationId: string,
    tournamentId: string,
    userId: string,
    dto: CreateTournamentApplicationDto,
  ): Promise<TournamentApplication> {
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, {
      id: tournamentId,
    });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }

    let player = await this.playerRepo.findOne({ where: { organizationId, userId } });
    if (!player) {
      player = await this.playersService.create(organizationId, { ...dto, userId });
    }

    try {
      return await this.applicationRepo.save(
        this.applicationRepo.create({
          tournamentId,
          userId,
          playerId: player.id,
          status: TournamentApplicationStatus.PENDING,
        }),
      );
    } catch (err) {
      // Unique (tournamentId, userId) constraint — one application per user
      // per tournament, no resubmission flow in M1 (see entity doc comment).
      if ((err as { code?: string }).code === '23505') {
        throw new ConflictException('You have already applied to this tournament');
      }
      throw err;
    }
  }

  /** org_admin/tournament_admin: list applications for one tournament, optionally filtered by status. */
  async findAllForTournament(
    organizationId: string,
    tournamentId: string,
    status?: TournamentApplicationStatus,
  ): Promise<TournamentApplication[]> {
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, {
      id: tournamentId,
    });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }

    return this.applicationRepo.find({
      where: { tournamentId, ...(status ? { status } : {}) },
      relations: ['player'],
      order: { createdAt: 'ASC' },
    });
  }

  /**
   * The caller's own applications across every tournament in this org.
   * Deliberately NOT nested under a single tournament's route — a player
   * wants to see everything they've applied to org-wide, not just one
   * tournament — so this backs
   * GET /organizations/:organizationId/applications/mine rather than
   * .../tournaments/:tournamentId/applications/mine.
   */
  async findMine(organizationId: string, userId: string): Promise<TournamentApplication[]> {
    return this.applicationRepo
      .createQueryBuilder('application')
      .innerJoinAndSelect('application.tournament', 'tournament')
      .leftJoinAndSelect('application.player', 'player')
      .where('application.userId = :userId', { userId })
      .andWhere('tournament.organizationId = :organizationId', { organizationId })
      .orderBy('application.createdAt', 'DESC')
      .getMany();
  }

  /**
   * org_admin/tournament_admin: approve or reject an application.
   *
   * Deliberate scope boundary (not an oversight): approving here does NOT
   * automatically add the player to any auction pool or team roster — that
   * remains a separate manual admin action via the existing
   * Players/Auction endpoints.
   */
  async review(
    organizationId: string,
    tournamentId: string,
    applicationId: string,
    reviewerUserId: string,
    dto: ReviewTournamentApplicationDto,
  ): Promise<TournamentApplication> {
    if (dto.status === TournamentApplicationStatus.PENDING) {
      throw new BadRequestException('Cannot set review status back to pending');
    }

    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, {
      id: tournamentId,
    });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }

    const application = await this.applicationRepo.findOne({
      where: { id: applicationId, tournamentId },
    });
    if (!application) {
      throw new NotFoundException('Application not found');
    }

    application.status = dto.status;
    application.reviewNote = dto.note ?? null;
    application.reviewedByUserId = reviewerUserId;
    application.reviewedAt = new Date();
    const saved = await this.applicationRepo.save(application);

    const approved = dto.status === TournamentApplicationStatus.APPROVED;
    await this.notificationsService.notify(organizationId, [saved.userId], {
      type: NotificationType.PLAYER_APPROVAL,
      title: approved ? 'Application approved' : 'Application rejected',
      message: approved
        ? 'Your tournament application has been approved.'
        : `Your tournament application has been rejected.${dto.note ? ` Reason: ${dto.note}` : ''}`,
      relatedEntityType: 'tournament_application',
      relatedEntityId: saved.id,
    });

    return saved;
  }
}
