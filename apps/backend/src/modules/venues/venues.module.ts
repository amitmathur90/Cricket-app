import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Match } from '../../database/entities/match.entity';
import { Venue } from '../../database/entities/venue.entity';
import { VenueUnavailability } from '../../database/entities/venue-unavailability.entity';
import { VenuesController } from './venues.controller';
import { VenuesService } from './venues.service';

@Module({
  imports: [TypeOrmModule.forFeature([Venue, VenueUnavailability, Match])],
  controllers: [VenuesController],
  providers: [VenuesService],
  exports: [VenuesService],
})
export class VenuesModule {}
