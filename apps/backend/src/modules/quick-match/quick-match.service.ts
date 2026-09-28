import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tournament, TournamentFormat, TournamentStatus } from '../../database/entities/tournament.entity';

/**
 * Backs "Quick Match" — starting a match between two ad-hoc teams with no
 * tournament setup, the way CricHeroes' "Start a match" flow works. Rather
 * than duplicating team-registration/roster/lineup/scoring infrastructure
 * for a tournament-less context, every quick match actually lives inside
 * one hidden, auto-created tournament per organization (see
 * Tournament.isQuickMatchPool's doc comment) — the client never sees or
 * manages this tournament directly; it just calls getTournament() once to
 * get an id, then uses every EXISTING tournament-scoped endpoint (team
 * registration, roster, match creation, lineup, scoring) against it
 * exactly as a real tournament.
 */
@Injectable()
export class QuickMatchService {
  constructor(
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
  ) {}

  async getOrCreateTournament(organizationId: string, createdByUserId: string): Promise<Tournament> {
    const existing = await this.tournamentRepo.findOne({
      where: { organizationId, isQuickMatchPool: true },
    });
    if (existing) {
      return existing;
    }

    const today = new Date().toISOString().slice(0, 10);
    return this.tournamentRepo.save(
      this.tournamentRepo.create({
        organizationId,
        name: 'Quick Matches',
        format: TournamentFormat.CUSTOM,
        startDate: today,
        endDate: today,
        status: TournamentStatus.LIVE,
        isQuickMatchPool: true,
        createdByUserId,
      }),
    );
  }
}
