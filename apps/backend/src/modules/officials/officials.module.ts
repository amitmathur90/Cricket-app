import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Official } from '../../database/entities/official.entity';
import { OfficialsController } from './officials.controller';
import { OfficialsService } from './officials.service';

@Module({
  imports: [TypeOrmModule.forFeature([Official])],
  controllers: [OfficialsController],
  providers: [OfficialsService],
  exports: [OfficialsService],
})
export class OfficialsModule {}
