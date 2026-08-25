import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { findManyOrgScoped, findOneOrgScoped } from '../../common/base/org-scoped.repository';
import { Match } from '../../database/entities/match.entity';
import { Venue } from '../../database/entities/venue.entity';
import { VenueUnavailability } from '../../database/entities/venue-unavailability.entity';
import { CreateVenueUnavailabilityDto } from './dto/create-venue-unavailability.dto';
import { CreateVenueDto } from './dto/create-venue.dto';
import { UpdateVenueDto } from './dto/update-venue.dto';

export type VenueDayStatus = 'available' | 'booked' | 'maintenance';

export interface VenueAvailabilityDay {
  date: string; // YYYY-MM-DD
  status: VenueDayStatus;
}

@Injectable()
export class VenuesService {
  constructor(
    @InjectRepository(Venue) private readonly venueRepo: Repository<Venue>,
    @InjectRepository(VenueUnavailability)
    private readonly unavailabilityRepo: Repository<VenueUnavailability>,
    @InjectRepository(Match) private readonly matchRepo: Repository<Match>,
  ) {}

  async create(organizationId: string, dto: CreateVenueDto): Promise<Venue> {
    return this.venueRepo.save(this.venueRepo.create({ ...dto, organizationId }));
  }

  async findAll(organizationId: string): Promise<Venue[]> {
    return findManyOrgScoped(this.venueRepo, organizationId);
  }

  async findOne(organizationId: string, venueId: string): Promise<Venue> {
    const venue = await findOneOrgScoped(this.venueRepo, organizationId, { id: venueId });
    if (!venue) {
      throw new NotFoundException('Venue not found');
    }
    return venue;
  }

  async update(organizationId: string, venueId: string, dto: UpdateVenueDto): Promise<Venue> {
    const venue = await this.findOne(organizationId, venueId);
    Object.assign(venue, dto);
    return this.venueRepo.save(venue);
  }

  async remove(organizationId: string, venueId: string): Promise<void> {
    const venue = await this.findOne(organizationId, venueId);
    await this.venueRepo.remove(venue);
  }

  // --- Unavailability ("Maintenance") ---

  async addUnavailability(
    organizationId: string,
    venueId: string,
    dto: CreateVenueUnavailabilityDto,
  ): Promise<VenueUnavailability> {
    await this.findOne(organizationId, venueId); // verifies org ownership
    return this.unavailabilityRepo.save(
      this.unavailabilityRepo.create({ venueId, date: dto.date, reason: dto.reason ?? null }),
    );
  }

  async listUnavailability(organizationId: string, venueId: string): Promise<VenueUnavailability[]> {
    await this.findOne(organizationId, venueId);
    return this.unavailabilityRepo.find({ where: { venueId }, order: { date: 'ASC' } });
  }

  async removeUnavailability(organizationId: string, venueId: string, unavailabilityId: string): Promise<void> {
    await this.findOne(organizationId, venueId);
    const row = await this.unavailabilityRepo.findOne({ where: { id: unavailabilityId, venueId } });
    if (!row) {
      throw new NotFoundException('Unavailability record not found');
    }
    await this.unavailabilityRepo.remove(row);
  }

  private parseDate(value: string, field: string): Date {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException(`Invalid ${field} date`);
    }
    return date;
  }

  /** YYYY-MM-DD in UTC, matching how `date`-typed columns round-trip as strings. */
  private toDateKey(date: Date): string {
    return date.toISOString().slice(0, 10);
  }

  /**
   * Day-by-day availability calendar for `[from, to]` (inclusive), combining:
   *  - "booked": any `Match` at this venue (`venueId`) with a `scheduledAt`
   *    falling on that day (same Between() date-range pattern as
   *    `MatchesService.findAll`).
   *  - "maintenance": an explicit `VenueUnavailability` row for that day.
   *  - "available": neither of the above.
   *
   * Precedence: BOOKED wins over MAINTENANCE if a day somehow has both (an
   * admin marked a day under maintenance after a match was already
   * scheduled there, or vice versa) — a real, already-scheduled match is
   * treated as the more actionable/urgent fact for anyone reading the
   * calendar, since cancelling/moving a live fixture has bigger
   * consequences than an unavailability record no one has enforced against
   * bookings yet. This is a display precedence only; it does not prevent
   * either state from being created (no cross-validation between the two).
   */
  async getAvailability(
    organizationId: string,
    venueId: string,
    from: string,
    to: string,
  ): Promise<VenueAvailabilityDay[]> {
    await this.findOne(organizationId, venueId);

    const fromDate = this.parseDate(from, 'from');
    const toDate = this.parseDate(to, 'to');
    if (fromDate > toDate) {
      throw new BadRequestException('from must not be after to');
    }

    const fromKey = this.toDateKey(fromDate);
    const toKey = this.toDateKey(toDate);

    const [matches, unavailability] = await Promise.all([
      this.matchRepo.find({
        where: {
          venueId,
          scheduledAt: Between(new Date(`${fromKey}T00:00:00.000Z`), new Date(`${toKey}T23:59:59.999Z`)),
        },
      }),
      this.unavailabilityRepo.find({
        where: { venueId, date: Between(fromKey, toKey) },
      }),
    ]);

    const bookedDays = new Set(
      matches.filter((m) => m.scheduledAt).map((m) => this.toDateKey(new Date(m.scheduledAt as Date))),
    );
    const maintenanceDays = new Set(unavailability.map((u) => u.date));

    const days: VenueAvailabilityDay[] = [];
    const cursor = new Date(`${fromKey}T00:00:00.000Z`);
    const end = new Date(`${toKey}T00:00:00.000Z`);
    while (cursor <= end) {
      const key = this.toDateKey(cursor);
      let status: VenueDayStatus = 'available';
      if (bookedDays.has(key)) {
        status = 'booked';
      } else if (maintenanceDays.has(key)) {
        status = 'maintenance';
      }
      days.push({ date: key, status });
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }
    return days;
  }
}
