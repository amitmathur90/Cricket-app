import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Player } from '../../database/entities/player.entity';
import { PracticeAttendance } from '../../database/entities/practice-attendance.entity';
import { PracticeSession } from '../../database/entities/practice-session.entity';
import { Team } from '../../database/entities/team.entity';
import { MarkAttendanceDto } from './dto/mark-attendance.dto';

/** Eager-loaded so responses include player name/photo, not just playerId. */
const RESPONSE_RELATIONS = ['player'];

/**
 * Practice attendance is tracked against the org-level `Player` directly,
 * NOT a tournament roster (`team_players` requires a `tournament_team`,
 * which a practice session deliberately has none of). Any `playerId` that
 * resolves to a valid org-level player is accepted here — there is no
 * "must be on this team's roster" enforcement. Which players are offered as
 * attendance-markable (all org players? the team's most recent tournament
 * roster, if any?) is left as a Flutter-side UI concern, not a backend
 * invariant.
 */
@Injectable()
export class PracticeAttendanceService {
  constructor(
    @InjectRepository(PracticeAttendance)
    private readonly attendanceRepo: Repository<PracticeAttendance>,
    @InjectRepository(PracticeSession)
    private readonly sessionRepo: Repository<PracticeSession>,
    @InjectRepository(Team) private readonly teamRepo: Repository<Team>,
    @InjectRepository(Player) private readonly playerRepo: Repository<Player>,
  ) {}

  /** Verifies the session belongs to the org + team and returns it, or throws NotFoundException. */
  private async getOrgScopedSession(
    organizationId: string,
    teamId: string,
    sessionId: string,
  ): Promise<PracticeSession> {
    const team = await findOneOrgScoped(this.teamRepo, organizationId, { id: teamId });
    if (!team) {
      throw new NotFoundException('Team not found');
    }
    const session = await this.sessionRepo.findOne({ where: { id: sessionId, organizationId, teamId } });
    if (!session) {
      throw new NotFoundException('Practice session not found');
    }
    return session;
  }

  /**
   * Only returns rows that actually exist. A roster player with no row for
   * this session is "not yet marked" — the response does not synthesize a
   * default "absent" placeholder. Simplest option; the Flutter client
   * decides how to render "not yet marked" (e.g. against its own player
   * list) for players missing from this list.
   */
  async getAttendance(
    organizationId: string,
    teamId: string,
    sessionId: string,
  ): Promise<PracticeAttendance[]> {
    await this.getOrgScopedSession(organizationId, teamId, sessionId);
    return this.attendanceRepo.find({
      where: { practiceSessionId: sessionId },
      relations: RESPONSE_RELATIONS,
      order: { markedAt: 'ASC' },
    });
  }

  /**
   * Bulk create-or-update: for each `(practiceSessionId, playerId)` pair,
   * updates the existing row's status + markedAt if one exists, otherwise
   * creates it. Runs inside a transaction so a concurrent GET never
   * observes a half-written batch.
   */
  async markAttendance(
    organizationId: string,
    teamId: string,
    sessionId: string,
    dto: MarkAttendanceDto,
  ): Promise<PracticeAttendance[]> {
    await this.getOrgScopedSession(organizationId, teamId, sessionId);

    const playerIds = [...new Set(dto.entries.map((entry) => entry.playerId))];
    if (playerIds.length !== dto.entries.length) {
      throw new BadRequestException('Duplicate playerId in attendance submission');
    }

    const players = await this.playerRepo.find({
      where: { id: In(playerIds), organizationId },
    });
    if (players.length !== playerIds.length) {
      throw new BadRequestException('All playerIds must be players belonging to this organization');
    }

    const markedAt = new Date();

    await this.attendanceRepo.manager.transaction(async (manager) => {
      const repo = manager.getRepository(PracticeAttendance);
      const existingRows = await repo.find({
        where: { practiceSessionId: sessionId, playerId: In(playerIds) },
      });
      const existingByPlayerId = new Map(existingRows.map((row) => [row.playerId, row]));

      for (const entry of dto.entries) {
        const existing = existingByPlayerId.get(entry.playerId);
        if (existing) {
          existing.status = entry.status;
          existing.markedAt = markedAt;
          await repo.save(existing);
        } else {
          await repo.save(
            repo.create({
              practiceSessionId: sessionId,
              playerId: entry.playerId,
              status: entry.status,
              markedAt,
            }),
          );
        }
      }
    });

    return this.getAttendance(organizationId, teamId, sessionId);
  }
}
