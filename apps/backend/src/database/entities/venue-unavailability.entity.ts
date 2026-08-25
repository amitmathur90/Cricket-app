import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Venue } from './venue.entity';

/**
 * An explicit "this venue is unavailable on this date" record — covers the
 * "Maintenance" status on the venue availability calendar, which (unlike
 * "Booked") cannot be derived from `Match` rows. See `VenuesService.getAvailability`
 * for how this combines with matches to produce the day-by-day calendar;
 * `reason` is free text (e.g. "Maintenance", "Ground re-turfing") rather than
 * an enum since this is deliberately a generic "blocked" record, not
 * exclusively a maintenance tracker.
 */
@Entity({ name: 'venue_unavailability' })
export class VenueUnavailability {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'venue_id', type: 'uuid' })
  venueId: string;

  @ManyToOne(() => Venue, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'venue_id' })
  venue: Venue;

  @Column({ type: 'date' })
  date: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  reason: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
