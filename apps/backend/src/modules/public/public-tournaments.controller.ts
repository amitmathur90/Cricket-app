import { Controller, Get, NotFoundException, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam, TournamentTeamStatus } from '../../database/entities/tournament-team.entity';
import { MatchesService } from '../matches/matches.service';
import { ScoringRealtimeService } from '../scoring/scoring-realtime.service';
import { TournamentsService } from '../tournaments/tournaments.service';

/**
 * Column-level allow-list for every public tournament read — deliberately
 * an explicit `FindOptionsSelect`, not a mapped subset of a full entity
 * fetch, so a new sensitive column added to `Tournament` later (financial,
 * contact info, internal notes) does NOT silently leak here just because it
 * was added to the entity. Notably omits: contactEmail, contactPhone,
 * playerRegistrationFee, teamRegistrationFee, tournamentRules, matchRules,
 * pointsSystem, tieBreakerRules, registrationOpensAt/ClosesAt,
 * organizationId, createdByUserId.
 */
const PUBLIC_TOURNAMENT_SELECT = {
  id: true,
  name: true,
  format: true,
  startDate: true,
  endDate: true,
  status: true,
  logoUrl: true,
  location: true,
  description: true,
  organizerName: true,
  numberOfTeams: true,
} as const;

/**
 * Public (fully unauthenticated) read-only surface for the mobile app's
 * "public fan section" — see PublicModule doc for why no guards are applied
 * here and how that was confirmed safe (no global APP_GUARD in this app).
 */
@ApiTags('public')
@Controller('public/organizations/:organizationId/tournaments')
export class PublicTournamentsController {
  constructor(
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentTeam) private readonly tournamentTeamRepo: Repository<TournamentTeam>,
    private readonly matchesService: MatchesService,
    private readonly tournamentsService: TournamentsService,
    private readonly scoringRealtimeService: ScoringRealtimeService,
  ) {}

  private async getOrgScopedTournamentOrThrow(
    organizationId: string,
    tournamentId: string,
  ): Promise<Partial<Tournament>> {
    const tournament = await this.tournamentRepo.findOne({
      where: { id: tournamentId, organizationId },
      select: PUBLIC_TOURNAMENT_SELECT,
    });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }
    return tournament;
  }

  @Get()
  @ApiOperation({ summary: '[Public] List tournaments — name, format, dates, status, logo only' })
  async findAll(@Param('organizationId', ParseUUIDPipe) organizationId: string) {
    return this.tournamentRepo.find({
      where: { organizationId },
      select: PUBLIC_TOURNAMENT_SELECT,
      order: { startDate: 'ASC' },
    });
  }

  @Get(':tournamentId')
  @ApiOperation({ summary: '[Public] Tournament detail' })
  async findOne(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    return this.getOrgScopedTournamentOrThrow(organizationId, tournamentId);
  }

  @Get(':tournamentId/teams')
  @ApiOperation({
    summary:
      '[Public] Teams registered in a tournament — name and logo only, no purse/financial data. ' +
      'Withdrawn teams are excluded.',
  })
  async getTeams(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    await this.getOrgScopedTournamentOrThrow(organizationId, tournamentId);

    const rows = await this.tournamentTeamRepo.find({
      where: { tournamentId, status: TournamentTeamStatus.REGISTERED },
      relations: ['team'],
    });
    return rows.map((row) => ({
      tournamentTeamId: row.id,
      teamId: row.team.id,
      name: row.team.name,
      shortCode: row.team.shortCode,
      logoUrl: row.team.logoUrl,
    }));
  }

  @Get(':tournamentId/matches')
  @ApiOperation({
    summary:
      "[Public] Fixtures/results for a tournament — reuses MatchesService's team-name resolution, then " +
      'strips anything not public-safe (umpire/scorer/match-referee contact details in particular).',
  })
  async getMatches(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    await this.getOrgScopedTournamentOrThrow(organizationId, tournamentId);
    const matches = await this.matchesService.findAll(organizationId, tournamentId, {});
    // Deliberately NOT a raw pass-through: MatchesService's response eager-
    // loads full umpireOfficial/scorerOfficial/matchRefereeOfficial objects,
    // which carry Official.phone/Official.email (PII) — those are never
    // spread into this response.
    return matches.map((m) => ({
      id: m.id,
      tournamentId: m.tournamentId,
      homeTournamentTeamId: m.homeTournamentTeamId,
      awayTournamentTeamId: m.awayTournamentTeamId,
      homeTeamName: m.homeTeamName,
      awayTeamName: m.awayTeamName,
      winnerTournamentTeamId: m.winnerTournamentTeamId,
      winnerTeamName: m.winnerTeamName,
      scheduledAt: m.scheduledAt,
      venueName: m.venue?.name ?? m.venueName,
      status: m.status,
      resultSummary: m.resultSummary,
      oversLimit: m.oversLimit,
    }));
  }

  @Get(':tournamentId/points-table')
  @ApiOperation({
    summary: '[Public] Computed points table (standings) — reuses TournamentsService.getPointsTable verbatim',
  })
  async getPointsTable(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
  ) {
    // getPointsTable already 404s for a tournamentId not belonging to this
    // org, so no separate existence check is needed — every field it
    // returns (team name, played/won/lost/tied, points, NRR) is already
    // public-safe with nothing further to redact.
    return this.tournamentsService.getPointsTable(organizationId, tournamentId);
  }

  @Get(':tournamentId/live-score/:matchId')
  @ApiOperation({
    summary:
      '[Public] Live scoring snapshot for the "LIVE NOW" home card — reuses ' +
      'ScoringRealtimeService.getLiveState verbatim',
  })
  async getLiveScore(
    @Param('organizationId', ParseUUIDPipe) organizationId: string,
    @Param('tournamentId', ParseUUIDPipe) tournamentId: string,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ) {
    // MatchesService.findOne 404s unless matchId belongs to BOTH this org
    // AND this tournamentId — enforces the URL's tournament scoping before
    // falling through to the org-only-scoped getLiveState. Its result is
    // discarded; only the 404-or-not check is needed here.
    await this.matchesService.findOne(organizationId, tournamentId, matchId);
    // Live state is built entirely from player names + ball-by-ball figures
    // — no PII (no phone/email anywhere in this response), safe to return
    // exactly as the authenticated scoring endpoints do.
    return this.scoringRealtimeService.getLiveState(organizationId, matchId);
  }
}
