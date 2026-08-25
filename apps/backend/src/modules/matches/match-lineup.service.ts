import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Match } from '../../database/entities/match.entity';
import { MatchLineup, MatchLineupRole } from '../../database/entities/match-lineup.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { SetLineupDto } from './dto/set-lineup.dto';

/** Relations eager-loaded so the response includes player details, mirroring TeamsService.getRoster. */
const LINEUP_RELATIONS = ['teamPlayer', 'teamPlayer.player'];

export interface TeamLineupResponse {
  tournamentTeamId: string;
  playing: MatchLineup[];
  substitutes: MatchLineup[];
}

export interface MatchLineupResponse {
  matchId: string;
  home: TeamLineupResponse | null;
  away: TeamLineupResponse | null;
}

/**
 * Per-match, per-team Playing XI / substitute selection. Lives on its own
 * `match_lineups` table (not on `team_players`) because a squad's Playing XI
 * can differ from match to match within the same tournament.
 *
 * Auth note: the spec frames this as "Captain selects Playing XI", but the
 * app has no per-user "I am team X's captain" linkage beyond org role — so
 * the controller allows org_admin/tournament_admin/team_owner, with
 * team_owner standing in as the closest existing proxy for "someone
 * authorized to manage this team's matchday selection". Not a precise model
 * of "the captain", just the nearest available role.
 */
@Injectable()
export class MatchLineupService {
  constructor(
    @InjectRepository(Match) private readonly matchRepo: Repository<Match>,
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TeamPlayer) private readonly teamPlayerRepo: Repository<TeamPlayer>,
    @InjectRepository(MatchLineup) private readonly lineupRepo: Repository<MatchLineup>,
  ) {}

  private async getOrgScopedMatch(
    organizationId: string,
    tournamentId: string,
    matchId: string,
  ): Promise<Match> {
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, { id: tournamentId });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }
    const match = await this.matchRepo.findOne({ where: { id: matchId, tournamentId } });
    if (!match) {
      throw new NotFoundException('Match not found');
    }
    return match;
  }

  private async getTeamLineup(matchId: string, tournamentTeamId: string): Promise<TeamLineupResponse> {
    const rows = await this.lineupRepo.find({
      where: { matchId, tournamentTeamId },
      relations: LINEUP_RELATIONS,
      order: { createdAt: 'ASC' },
    });
    return {
      tournamentTeamId,
      playing: rows.filter((row) => row.role === MatchLineupRole.PLAYING),
      substitutes: rows.filter((row) => row.role === MatchLineupRole.SUBSTITUTE),
    };
  }

  /**
   * Full replace: deletes this team's existing `match_lineups` rows for the
   * match and re-creates them from the submitted arrays, inside a
   * transaction so a concurrent GET never observes a half-written state.
   *
   * Playing-XI-size enforcement: deliberately NOT enforced here (no "must be
   * exactly 11" check). The backend accepts any valid subset of the team's
   * roster — including a partial, in-progress selection — so the Flutter UI
   * is free to let a captain save a draft before it has 11 players. The
   * "exactly 11 to submit as final" rule is a client-side UX rule, not a
   * server invariant.
   */
  async setLineup(
    organizationId: string,
    tournamentId: string,
    matchId: string,
    tournamentTeamId: string,
    dto: SetLineupDto,
  ): Promise<TeamLineupResponse> {
    const match = await this.getOrgScopedMatch(organizationId, tournamentId, matchId);

    if (tournamentTeamId !== match.homeTournamentTeamId && tournamentTeamId !== match.awayTournamentTeamId) {
      throw new BadRequestException("tournamentTeamId must be this match's home or away team");
    }

    const playingIds = dto.playingTeamPlayerIds;
    const subIds = dto.substituteTeamPlayerIds;

    const overlap = playingIds.filter((id) => subIds.includes(id));
    if (overlap.length > 0) {
      throw new BadRequestException(
        'A teamPlayerId cannot appear in both playingTeamPlayerIds and substituteTeamPlayerIds',
      );
    }

    const allIds = [...playingIds, ...subIds];
    const uniqueIds = new Set(allIds);
    if (uniqueIds.size !== allIds.length) {
      throw new BadRequestException('Duplicate teamPlayerId in lineup submission');
    }

    if (uniqueIds.size > 0) {
      const rows = await this.teamPlayerRepo.find({
        where: { id: In([...uniqueIds]), tournamentTeamId },
      });
      if (rows.length !== uniqueIds.size) {
        throw new BadRequestException(
          "All teamPlayerIds must be team_players rows belonging to this team's roster",
        );
      }
    }

    await this.lineupRepo.manager.transaction(async (manager) => {
      const repo = manager.getRepository(MatchLineup);
      await repo.delete({ matchId, tournamentTeamId });

      const rowsToInsert = [
        ...playingIds.map((teamPlayerId) => ({
          matchId,
          tournamentTeamId,
          teamPlayerId,
          role: MatchLineupRole.PLAYING,
        })),
        ...subIds.map((teamPlayerId) => ({
          matchId,
          tournamentTeamId,
          teamPlayerId,
          role: MatchLineupRole.SUBSTITUTE,
        })),
      ];
      if (rowsToInsert.length > 0) {
        await repo.insert(rowsToInsert);
      }
    });

    return this.getTeamLineup(matchId, tournamentTeamId);
  }

  async getLineup(organizationId: string, tournamentId: string, matchId: string): Promise<MatchLineupResponse> {
    const match = await this.getOrgScopedMatch(organizationId, tournamentId, matchId);

    const [home, away] = await Promise.all([
      match.homeTournamentTeamId
        ? this.getTeamLineup(matchId, match.homeTournamentTeamId)
        : Promise.resolve(null),
      match.awayTournamentTeamId
        ? this.getTeamLineup(matchId, match.awayTournamentTeamId)
        : Promise.resolve(null),
    ]);

    return { matchId, home, away };
  }
}
