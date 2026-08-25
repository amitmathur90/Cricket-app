import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, FindOptionsWhere, In, Repository } from 'typeorm';
import { findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Match, MatchStatus } from '../../database/entities/match.entity';
import { NotificationType } from '../../database/entities/notification.entity';
import { Official } from '../../database/entities/official.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { Venue } from '../../database/entities/venue.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';

export interface FindMatchesFilters {
  status?: string;
  from?: string;
  to?: string;
}

/**
 * Relations eager-loaded for every response so the Flutter match card can
 * render "Tigers vs Warriors" without a second round trip to cross-reference
 * an already-fetched teams list. Decision: resolve names server-side (see
 * `toResponse`) rather than leaving the join to the client — it's strictly
 * less client-side plumbing for a field every match card needs, and the
 * relation chain (match -> tournament_team -> team) isn't something the
 * client can walk on its own without also fetching tournament_teams.
 */
const RESPONSE_RELATIONS = [
  'homeTournamentTeam',
  'homeTournamentTeam.team',
  'awayTournamentTeam',
  'awayTournamentTeam.team',
  'winnerTournamentTeam',
  'winnerTournamentTeam.team',
  // Dual-field approach (see Match entity doc): unlike home/away/winner
  // team ids, these are resolved to full nested objects rather than a bare
  // name string, since they're optional supplements to the legacy free-text
  // venueName/umpireName/scorerName fields (which remain untouched below).
  'venue',
  'umpireOfficial',
  'scorerOfficial',
  'matchRefereeOfficial',
];

/** A `Match` entity with team ids resolved to display names, joined relations stripped. */
export type MatchResponse = Omit<
  Match,
  'homeTournamentTeam' | 'awayTournamentTeam' | 'winnerTournamentTeam' | 'tournament' | 'createdByUser'
> & {
  homeTeamName: string | null;
  awayTeamName: string | null;
  winnerTeamName: string | null;
};

@Injectable()
export class MatchesService {
  constructor(
    @InjectRepository(Match) private readonly matchRepo: Repository<Match>,
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentTeam)
    private readonly tournamentTeamRepo: Repository<TournamentTeam>,
    @InjectRepository(Venue) private readonly venueRepo: Repository<Venue>,
    @InjectRepository(Official) private readonly officialRepo: Repository<Official>,
    private readonly notificationsService: NotificationsService,
  ) {}

  /** Verifies the tournament belongs to the org and returns it, or throws NotFoundException. */
  private async getOrgScopedTournament(organizationId: string, tournamentId: string): Promise<Tournament> {
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, { id: tournamentId });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }
    return tournament;
  }

  private toResponse(match: Match): MatchResponse {
    const { homeTournamentTeam, awayTournamentTeam, winnerTournamentTeam, tournament, createdByUser, ...rest } =
      match;
    return {
      ...rest,
      homeTeamName: homeTournamentTeam?.team?.name ?? null,
      awayTeamName: awayTournamentTeam?.team?.name ?? null,
      winnerTeamName: winnerTournamentTeam?.team?.name ?? null,
    };
  }

  private parseDate(value: string, field: string): Date {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`Invalid ${field} date`);
    }
    return date;
  }

  /**
   * Validates (a) a team can't play itself — checked against the FINAL
   * merged home/away pair, since on update either side may be left
   * unchanged — and (b) any team id being set in this call belongs to a
   * `tournament_teams` row for the SAME tournament as the match (tenancy
   * consistency, not just org scoping: a tournament_teams id from a
   * different tournament in the same org must still be rejected).
   */
  private async validateTeamAssignment(
    tournamentId: string,
    dto: Pick<CreateMatchDto, 'homeTournamentTeamId' | 'awayTournamentTeamId'>,
    existing?: Match,
  ): Promise<void> {
    const finalHome =
      dto.homeTournamentTeamId !== undefined ? dto.homeTournamentTeamId : existing?.homeTournamentTeamId;
    const finalAway =
      dto.awayTournamentTeamId !== undefined ? dto.awayTournamentTeamId : existing?.awayTournamentTeamId;

    if (finalHome && finalAway && finalHome === finalAway) {
      throw new BadRequestException('homeTournamentTeamId and awayTournamentTeamId must differ');
    }

    const idsToVerify = [dto.homeTournamentTeamId, dto.awayTournamentTeamId].filter(
      (id): id is string => id !== undefined && id !== null,
    );
    if (idsToVerify.length === 0) {
      return;
    }

    const rows = await this.tournamentTeamRepo.find({
      where: { id: In(idsToVerify), tournamentId },
    });
    if (rows.length !== idsToVerify.length) {
      throw new BadRequestException(
        'homeTournamentTeamId/awayTournamentTeamId must be tournament_teams rows belonging to this tournament',
      );
    }
  }

  /**
   * Validates that any provided venueId/umpireOfficialId/scorerOfficialId/
   * matchRefereeOfficialId is a real row belonging to THIS organization —
   * the org-scoping half of the dual-field approach (see Match entity doc).
   * Does not enforce that an `officialId` references an `Official` with the
   * matching `role` (e.g. umpireOfficialId -> role=umpire); that's left as
   * an org-admin convention rather than a hard constraint, consistent with
   * how the rest of this module keeps validation lightweight.
   */
  private async validateAssignedRecords(
    organizationId: string,
    dto: Pick<CreateMatchDto, 'venueId' | 'umpireOfficialId' | 'scorerOfficialId' | 'matchRefereeOfficialId'>,
  ): Promise<void> {
    if (dto.venueId) {
      const venue = await findOneOrgScoped(this.venueRepo, organizationId, { id: dto.venueId });
      if (!venue) {
        throw new BadRequestException('venueId must be a venues row belonging to this organization');
      }
    }
    const officialIds = [dto.umpireOfficialId, dto.scorerOfficialId, dto.matchRefereeOfficialId].filter(
      (id): id is string => id !== undefined && id !== null,
    );
    if (officialIds.length > 0) {
      const rows = await this.officialRepo.find({ where: { id: In(officialIds), organizationId } });
      if (rows.length !== new Set(officialIds).size) {
        throw new BadRequestException(
          'umpireOfficialId/scorerOfficialId/matchRefereeOfficialId must be officials rows belonging to this organization',
        );
      }
    }
  }

  async create(
    organizationId: string,
    tournamentId: string,
    dto: CreateMatchDto,
    createdByUserId: string,
  ): Promise<MatchResponse> {
    await this.getOrgScopedTournament(organizationId, tournamentId);
    await this.validateTeamAssignment(tournamentId, dto);
    await this.validateAssignedRecords(organizationId, dto);

    const match = await this.matchRepo.save(
      this.matchRepo.create({
        tournamentId,
        homeTournamentTeamId: dto.homeTournamentTeamId ?? null,
        awayTournamentTeamId: dto.awayTournamentTeamId ?? null,
        scheduledAt: dto.scheduledAt ? this.parseDate(dto.scheduledAt, 'scheduledAt') : null,
        venueName: dto.venueName ?? null,
        umpireName: dto.umpireName ?? null,
        scorerName: dto.scorerName ?? null,
        venueId: dto.venueId ?? null,
        umpireOfficialId: dto.umpireOfficialId ?? null,
        scorerOfficialId: dto.scorerOfficialId ?? null,
        matchRefereeOfficialId: dto.matchRefereeOfficialId ?? null,
        createdByUserId,
      }),
    );
    return this.findOne(organizationId, tournamentId, match.id);
  }

  async findAll(
    organizationId: string,
    tournamentId: string,
    filters: FindMatchesFilters,
  ): Promise<MatchResponse[]> {
    await this.getOrgScopedTournament(organizationId, tournamentId);

    const where: FindOptionsWhere<Match> = { tournamentId };
    if (filters.status) {
      if (!Object.values(MatchStatus).includes(filters.status as MatchStatus)) {
        throw new BadRequestException(`Invalid status filter: ${filters.status}`);
      }
      where.status = filters.status as MatchStatus;
    }
    // Between() compiles to a SQL BETWEEN, which never matches a NULL
    // column — so matches with no scheduledAt are naturally excluded
    // whenever a date-range filter is supplied, per spec.
    if (filters.from || filters.to) {
      const from = filters.from ? this.parseDate(filters.from, 'from') : new Date(0);
      const to = filters.to ? this.parseDate(filters.to, 'to') : new Date(8640000000000000);
      where.scheduledAt = Between(from, to);
    }

    const matches = await this.matchRepo.find({
      where,
      relations: RESPONSE_RELATIONS,
      order: { scheduledAt: 'ASC' }, // Postgres default: NULLS LAST on ASC
    });
    return matches.map((match) => this.toResponse(match));
  }

  async findOne(organizationId: string, tournamentId: string, matchId: string): Promise<MatchResponse> {
    await this.getOrgScopedTournament(organizationId, tournamentId);
    const match = await this.matchRepo.findOne({
      where: { id: matchId, tournamentId },
      relations: RESPONSE_RELATIONS,
    });
    if (!match) {
      throw new NotFoundException('Match not found');
    }
    return this.toResponse(match);
  }

  /** Internal helper — returns the bare entity (no relations/computed fields), for update/remove. */
  private async findOneEntity(organizationId: string, tournamentId: string, matchId: string): Promise<Match> {
    await this.getOrgScopedTournament(organizationId, tournamentId);
    const match = await this.matchRepo.findOne({ where: { id: matchId, tournamentId } });
    if (!match) {
      throw new NotFoundException('Match not found');
    }
    return match;
  }

  /**
   * Single generic PATCH covering every distinct admin action: assign
   * teams/venue/umpire/scorer, reschedule, and status transitions —
   * including the soft "Cancel match" action (`{ status: 'cancelled' }`).
   */
  async update(
    organizationId: string,
    tournamentId: string,
    matchId: string,
    dto: UpdateMatchDto,
  ): Promise<MatchResponse> {
    const match = await this.findOneEntity(organizationId, tournamentId, matchId);
    await this.validateTeamAssignment(tournamentId, dto, match);
    await this.validateAssignedRecords(organizationId, dto);

    const previousScheduledAt = match.scheduledAt;
    const { scheduledAt, ...rest } = dto;
    Object.assign(match, rest);
    if (scheduledAt !== undefined) {
      match.scheduledAt = this.parseDate(scheduledAt, 'scheduledAt');
    }

    await this.matchRepo.save(match);

    if (
      scheduledAt !== undefined &&
      (previousScheduledAt?.getTime() ?? null) !== (match.scheduledAt?.getTime() ?? null)
    ) {
      await this.notifyScheduleChange(organizationId, match);
    }

    return this.findOne(organizationId, tournamentId, matchId);
  }

  /**
   * Notifies the two teams' owners (`Team.ownerUserId`) when a match is
   * rescheduled. Recipients are whichever owner(s) happen to be set — a
   * team with no owner assigned just silently gets no notification for
   * this match, per spec (not an error).
   */
  private async notifyScheduleChange(organizationId: string, match: Match): Promise<void> {
    const tournamentTeamIds = [match.homeTournamentTeamId, match.awayTournamentTeamId].filter(
      (id): id is string => !!id,
    );
    if (tournamentTeamIds.length === 0) {
      return;
    }
    const tournamentTeams = await this.tournamentTeamRepo.find({
      where: { id: In(tournamentTeamIds) },
      relations: ['team'],
    });
    const ownerUserIds = tournamentTeams.map((tt) => tt.team?.ownerUserId).filter((id): id is string => !!id);
    await this.notificationsService.notify(organizationId, ownerUserIds, {
      type: NotificationType.SCHEDULE_CHANGE,
      title: 'Match rescheduled',
      message: match.scheduledAt
        ? `Your match has been rescheduled to ${match.scheduledAt.toISOString()}`
        : 'Your match schedule has changed',
      relatedEntityType: 'match',
      relatedEntityId: match.id,
    });
  }

  /**
   * True hard delete — administrative cleanup only. The Flutter client's
   * "Cancel match" button should call `PATCH { status: 'cancelled' }`
   * instead (soft-cancel), which preserves the match's calendar/history
   * visibility; this endpoint actually removes the row.
   */
  async remove(organizationId: string, tournamentId: string, matchId: string): Promise<void> {
    const match = await this.findOneEntity(organizationId, tournamentId, matchId);
    await this.matchRepo.remove(match);
  }
}
