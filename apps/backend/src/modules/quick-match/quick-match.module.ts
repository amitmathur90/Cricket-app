import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Tournament } from '../../database/entities/tournament.entity';
import { QuickMatchController } from './quick-match.controller';
import { QuickMatchService } from './quick-match.service';

@Module({
  imports: [TypeOrmModule.forFeature([Tournament])],
  controllers: [QuickMatchController],
  providers: [QuickMatchService],
})
export class QuickMatchModule {}
