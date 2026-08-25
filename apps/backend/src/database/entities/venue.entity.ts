import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Organization } from './organization.entity';

export enum VenueStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
}

/**
 * A lightweight org-level venue/ground profile — same shape as `Coach`:
 * no login/user account, just enough identity (name, location, capacity,
 * pitch type, facilities, photo) to assign a real venue to a match instead
 * of (or in addition to) the free-text `Match.venueName` fallback. See
 * `VenueUnavailability` for the "Maintenance" side of the availability
 * calendar; "Booked" days are derived from `Match.venueId` + `scheduledAt`
 * rather than stored here.
 */
@Entity({ name: 'venues' })
export class Venue {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'varchar', length: 255, nullable: true })
  location: string | null;

  @Column({ type: 'int', nullable: true })
  capacity: number | null;

  /** Free text, e.g. "Grass", "Turf", "Matting" — deliberately not an enum. */
  @Column({ name: 'pitch_type', type: 'varchar', length: 100, nullable: true })
  pitchType: string | null;

  /** Free text list/description, e.g. "Parking, Floodlights, Pavilion". */
  @Column({ type: 'text', nullable: true })
  facilities: string | null;

  @Column({ name: 'photo_url', type: 'varchar', length: 512, nullable: true })
  photoUrl: string | null;

  @Column({ type: 'enum', enum: VenueStatus, default: VenueStatus.ACTIVE })
  status: VenueStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
