import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuctionPlayerPool } from '../../database/entities/auction-player-pool.entity';
import { FinanceTransaction } from '../../database/entities/finance-transaction.entity';
import { Sponsor } from '../../database/entities/sponsor.entity';
import { TeamPlayer } from '../../database/entities/team-player.entity';
import { Tournament } from '../../database/entities/tournament.entity';
import { TournamentTeam } from '../../database/entities/tournament-team.entity';
import { FinanceController } from './finance.controller';
import { FinanceService } from './finance.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      FinanceTransaction,
      Tournament,
      TournamentTeam,
      TeamPlayer,
      AuctionPlayerPool,
      Sponsor,
    ]),
  ],
  controllers: [FinanceController],
  providers: [FinanceService],
  exports: [FinanceService],
})
export class FinanceModule {}
