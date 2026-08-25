import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Not, Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Team } from '../../database/entities/team.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { CreateTeamDto } from './dto/create-team.dto';
import { RegisterTeamToTournamentDto } from './dto/register-team-to-tournament.dto';
import { UpdateRosterEntryDto } from './dto/update-roster-entry.dto';

@Injectable()
export class TeamsService {
  constructor(
    @InjectRepository(Team) private readonly teamRepo: Repository<Team>,
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentTeam)
    private readonly tournamentTeamRepo: Repository<TournamentTeam>,
    @InjectRepository(TeamPlayer) private readonly teamPlayerRepo: Repository<TeamPlayer>,
  ) {}

  async create(organizationId: string, dto: CreateTeamDto): Promise<Team> {
    return this.teamRepo.save(this.teamRepo.create({ ...dto, organizationId }));
  }

  async findAll(organizationId: string): Promise<Team[]> {
    return findManyOrgScoped(this.teamRepo, organizationId);
  }

  async findOne(organizationId: string, teamId: string): Promise<Team> {
    const team = await findOneOrgScoped(this.teamRepo, organizationId, { id: teamId });
    if (!team) {
      throw new NotFoundException('Team not found');
    }
    return team;
  }

  async remove(organizationId: string, teamId: string): Promise<void> {
    const team = await this.findOne(organizationId, teamId);
    await this.teamRepo.remove(team);
  }

  /** Registers an org-level team into a specific tournament (creates the tournament_teams row). */
  async registerToTournament(
    organizationId: string,
    teamId: string,
    tournamentId: string,
    dto: RegisterTeamToTournamentDto,
  ): Promise<TournamentTeam> {
    await this.findOne(organizationId, teamId);

    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, {
      id: tournamentId,
    });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }

    const existing = await this.tournamentTeamRepo.findOne({ where: { tournamentId, teamId } });
    if (existing) {
      throw new ConflictException('Team is already registered in this tournament');
    }

    const purseTotal = dto.purseTotal !== undefined ? dto.purseTotal.toFixed(2) : null;

    return this.tournamentTeamRepo.save(
      this.tournamentTeamRepo.create({
        tournamentId,
        teamId,
        groupId: dto.groupId ?? null,
        purseTotal,
        purseRemaining: purseTotal,
      }),
    );
  }

  /**
   * Lists a team's roster (squad) for a specific tournament, with player
   * details joined and the captain flagged — the read counterpart to
   * PlayersController.addToRoster, which was previously write-only.
   */
  async getRoster(
    organizationId: string,
    teamId: string,
    tournamentId: string,
  ): Promise<TeamPlayer[]> {
    await this.findOne(organizationId, teamId);

    const tournamentTeam = await this.tournamentTeamRepo.findOne({ where: { tournamentId, teamId } });
    if (!tournamentTeam) {
      throw new NotFoundException('Team is not registered in this tournament');
    }

    return this.teamPlayerRepo.find({
      where: { tournamentTeamId: tournamentTeam.id },
      relations: ['player'],
      order: { isCaptain: 'DESC' },
    });
  }

  /**
   * General roster-entry update — the write counterpart missing since
   * `addToRoster` (PlayersController) is create-only. Handles captain and
   * vice-captain flags, jersey number, and wicketkeeper status.
   *
   * Captain/vice-captain exclusivity is enforced here rather than pushed
   * onto callers:
   *  - at most one captain and one vice-captain per `tournament_team`:
   *    setting either flag to `true` on this entry atomically unsets it on
   *    every other roster entry for the same `tournament_team` (no separate
   *    "un-captain the old one first" step required by clients);
   *  - a single roster entry can never hold both flags at once.
   */
  async updateRosterEntry(
    organizationId: string,
    teamId: string,
    tournamentId: string,
    teamPlayerId: string,
    dto: UpdateRosterEntryDto,
  ): Promise<TeamPlayer> {
    await this.findOne(organizationId, teamId);

    const tournamentTeam = await this.tournamentTeamRepo.findOne({ where: { tournamentId, teamId } });
    if (!tournamentTeam) {
      throw new NotFoundException('Team is not registered in this tournament');
    }

    const teamPlayer = await this.teamPlayerRepo.findOne({
      where: { id: teamPlayerId, tournamentTeamId: tournamentTeam.id },
    });
    if (!teamPlayer) {
      throw new NotFoundException('Roster entry not found');
    }

    const finalIsCaptain = dto.isCaptain ?? teamPlayer.isCaptain;
    const finalIsViceCaptain = dto.isViceCaptain ?? teamPlayer.isViceCaptain;
    if (finalIsCaptain && finalIsViceCaptain) {
      throw new BadRequestException('A player cannot be both captain and vice-captain');
    }

    return this.teamPlayerRepo.manager.transaction(async (manager) => {
      const repo = manager.getRepository(TeamPlayer);

      if (dto.isCaptain === true) {
        await repo.update(
          { tournamentTeamId: tournamentTeam.id, id: Not(teamPlayerId) },
          { isCaptain: false },
        );
      }
      if (dto.isViceCaptain === true) {
        await repo.update(
          { tournamentTeamId: tournamentTeam.id, id: Not(teamPlayerId) },
          { isViceCaptain: false },
        );
      }

      if (dto.isCaptain !== undefined) {
        teamPlayer.isCaptain = dto.isCaptain;
      }
      if (dto.isViceCaptain !== undefined) {
        teamPlayer.isViceCaptain = dto.isViceCaptain;
      }
      if (dto.jerseyNumber !== undefined) {
        teamPlayer.jerseyNumber = dto.jerseyNumber;
      }
      if (dto.isWicketkeeper !== undefined) {
        teamPlayer.isWicketkeeper = dto.isWicketkeeper;
      }

      return repo.save(teamPlayer);
    });
  }
}
