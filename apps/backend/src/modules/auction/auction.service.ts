import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { AuctionBid } from '../../database/entities/auction-bid.entity';
import { AuctionPlayerPool } from '../../database/entities/auction-player-pool.entity';
import { AuctionSession } from '../../database/entities/auction-session.entity';
import { Player } from '../../database/entities/player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { AddToPoolDto } from './dto/add-to-pool.dto';
import { CreateAuctionSessionDto } from './dto/create-auction-session.dto';

@Injectable()
export class AuctionService {
  constructor(
    @InjectRepository(AuctionSession) private readonly sessionRepo: Repository<AuctionSession>,
    @InjectRepository(AuctionPlayerPool) private readonly poolRepo: Repository<AuctionPlayerPool>,
    @InjectRepository(AuctionBid) private readonly bidRepo: Repository<AuctionBid>,
    @InjectRepository(Player) private readonly playerRepo: Repository<Player>,
    @InjectRepository(Tournament) private readonly tournamentRepo: Repository<Tournament>,
    @InjectRepository(TournamentTeam)
    private readonly tournamentTeamRepo: Repository<TournamentTeam>,
  ) {}

  /** Verifies the tournament belongs to the org and returns it, or throws NotFoundException. */
  private async getOrgScopedTournament(organizationId: string, tournamentId: string): Promise<Tournament> {
    const tournament = await findOneOrgScoped(this.tournamentRepo, organizationId, { id: tournamentId });
    if (!tournament) {
      throw new NotFoundException('Tournament not found');
    }
    return tournament;
  }

  /** Loads a session and verifies (via its tournament) that it belongs to the org. */
  async getOrgScopedSession(organizationId: string, sessionId: string): Promise<AuctionSession> {
    const session = await this.sessionRepo.findOne({ where: { id: sessionId }, relations: ['tournament'] });
    if (!session || session.tournament.organizationId !== organizationId) {
      throw new NotFoundException('Auction session not found');
    }
    return session;
  }

  async create(
    organizationId: string,
    tournamentId: string,
    dto: CreateAuctionSessionDto,
  ): Promise<AuctionSession> {
    await this.getOrgScopedTournament(organizationId, tournamentId);
    return this.sessionRepo.save(
      this.sessionRepo.create({
        tournamentId,
        name: dto.name,
        bidIncrementRules: dto.bidIncrementRules ?? null,
      }),
    );
  }

  async findAll(organizationId: string, tournamentId: string): Promise<AuctionSession[]> {
    await this.getOrgScopedTournament(organizationId, tournamentId);
    return this.sessionRepo.find({ where: { tournamentId }, order: { createdAt: 'DESC' } });
  }

  async findOne(organizationId: string, sessionId: string): Promise<AuctionSession> {
    return this.getOrgScopedSession(organizationId, sessionId);
  }

  /** Bulk-adds players to a session's lot pool. Admin-only; validates org membership and no duplicates. */
  async addToPool(
    organizationId: string,
    sessionId: string,
    dto: AddToPoolDto,
  ): Promise<AuctionPlayerPool[]> {
    const session = await this.getOrgScopedSession(organizationId, sessionId);

    const playerIds = dto.entries.map((e) => e.playerId);
    const uniquePlayerIds = new Set(playerIds);
    if (uniquePlayerIds.size !== playerIds.length) {
      throw new BadRequestException('Duplicate playerId in request payload');
    }

    const players = await this.playerRepo.find({ where: { id: In(playerIds), organizationId } });
    if (players.length !== playerIds.length) {
      throw new BadRequestException('One or more players do not belong to this organization');
    }

    const existing = await this.poolRepo.find({
      where: { auctionSessionId: sessionId, playerId: In(playerIds) },
    });
    if (existing.length > 0) {
      throw new ConflictException(
        `Player(s) already in this session's pool: ${existing.map((e) => e.playerId).join(', ')}`,
      );
    }

    const entries = dto.entries.map((e) =>
      this.poolRepo.create({
        auctionSessionId: session.id,
        playerId: e.playerId,
        basePrice: e.basePrice.toFixed(2),
        lotOrder: e.lotOrder,
      }),
    );
    return this.poolRepo.save(entries);
  }

  async listPool(organizationId: string, sessionId: string): Promise<AuctionPlayerPool[]> {
    await this.getOrgScopedSession(organizationId, sessionId);
    return this.poolRepo.find({
      where: { auctionSessionId: sessionId },
      relations: ['player', 'soldToTeam', 'soldToTeam.team'],
      order: { lotOrder: 'ASC' },
    });
  }

  async listBids(organizationId: string, sessionId: string, playerId?: string): Promise<AuctionBid[]> {
    await this.getOrgScopedSession(organizationId, sessionId);

    if (playerId) {
      const poolEntry = await this.poolRepo.findOne({ where: { auctionSessionId: sessionId, playerId } });
      if (!poolEntry) {
        return [];
      }
      return this.bidRepo.find({
        where: { auctionPlayerPoolId: poolEntry.id },
        relations: ['team', 'team.team'],
        order: { bidSequence: 'ASC' },
      });
    }

    return this.bidRepo.find({
      where: { auctionSessionId: sessionId },
      relations: ['team', 'team.team'],
      order: { createdAt: 'ASC' },
    });
  }

  /** Per-team and per-player summary for a session, live-updating as lots resolve. */
  async getReport(organizationId: string, sessionId: string) {
    const session = await this.getOrgScopedSession(organizationId, sessionId);

    const [teams, poolEntries] = await Promise.all([
      this.tournamentTeamRepo.find({ where: { tournamentId: session.tournamentId }, relations: ['team'] }),
      this.poolRepo.find({
        where: { auctionSessionId: sessionId },
        relations: ['player', 'soldToTeam', 'soldToTeam.team'],
        order: { lotOrder: 'ASC' },
      }),
    ]);

    const teamSummaries = teams.map((team) => {
      const soldToThisTeam = poolEntries.filter((p) => p.soldToTeamId === team.id);
      const totalSpent = soldToThisTeam.reduce((sum, p) => sum + parseFloat(p.finalPrice ?? '0'), 0);
      return {
        tournamentTeamId: team.id,
        teamName: team.team.name,
        purseTotal: team.purseTotal,
        purseRemaining: team.purseRemaining,
        playersBought: soldToThisTeam.length,
        totalSpent: totalSpent.toFixed(2),
      };
    });

    const playerOutcomes = poolEntries.map((p) => ({
      playerId: p.playerId,
      playerName: p.player.fullName,
      status: p.status,
      basePrice: p.basePrice,
      finalPrice: p.finalPrice,
      soldToTeamId: p.soldToTeamId,
      soldToTeamName: p.soldToTeam?.team?.name ?? null,
    }));

    return {
      session: {
        id: session.id,
        name: session.name,
        status: session.status,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
      },
      teams: teamSummaries,
      players: playerOutcomes,
    };
  }

  /** All auction pool/bid history for one player across every session they've appeared in, org-scoped. */
  async getPlayerPurchaseHistory(organizationId: string, playerId: string) {
    const player = await findOneOrgScoped(this.playerRepo, organizationId, { id: playerId });
    if (!player) {
      throw new NotFoundException('Player not found');
    }

    const poolEntries = await this.poolRepo
      .createQueryBuilder('pool')
      .innerJoinAndSelect('pool.auctionSession', 'session')
      .innerJoinAndSelect('session.tournament', 'tournament')
      .leftJoinAndSelect('pool.soldToTeam', 'soldToTeam')
      .leftJoinAndSelect('soldToTeam.team', 'team')
      .where('pool.playerId = :playerId', { playerId })
      .andWhere('tournament.organizationId = :organizationId', { organizationId })
      .orderBy('session.createdAt', 'DESC')
      .getMany();

    if (poolEntries.length === 0) {
      return { playerId, playerName: player.fullName, history: [] };
    }

    const bids = await this.bidRepo.find({
      where: { auctionPlayerPoolId: In(poolEntries.map((p) => p.id)) },
      relations: ['team', 'team.team'],
      order: { bidSequence: 'ASC' },
    });

    const history = poolEntries.map((p) => ({
      auctionSessionId: p.auctionSessionId,
      auctionSessionName: p.auctionSession.name,
      tournamentId: p.auctionSession.tournamentId,
      status: p.status,
      basePrice: p.basePrice,
      finalPrice: p.finalPrice,
      soldToTeamId: p.soldToTeamId,
      soldToTeamName: p.soldToTeam?.team?.name ?? null,
      bids: bids
        .filter((b) => b.auctionPlayerPoolId === p.id)
        .map((b) => ({
          teamId: b.teamId,
          teamName: b.team.team.name,
          amount: b.bidAmount,
          bidSequence: b.bidSequence,
          createdAt: b.createdAt,
        })),
    }));

    return { playerId, playerName: player.fullName, history };
  }
}
