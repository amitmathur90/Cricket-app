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
import { User } from './user.entity';

export enum PlayerRole {
  BATSMAN = 'batsman',
  BOWLER = 'bowler',
  ALL_ROUNDER = 'all_rounder',
  WICKETKEEPER = 'wicketkeeper',
}

export enum PlayerStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
}

/**
 * 4-stage verification flow. Legal transitions (enforced in
 * PlayersService.setVerification):
 *   PENDING  -> VERIFIED (docs checked) or REJECTED
 *   VERIFIED -> APPROVED (fully cleared) or REJECTED
 *   APPROVED -> (terminal; rejecting an already-approved player doesn't fit this flow)
 *   REJECTED -> (terminal)
 * PENDING is never a valid transition *target* (only the initial default).
 */
export enum PlayerVerificationStatus {
  PENDING = 'pending',
  VERIFIED = 'verified',
  APPROVED = 'approved',
  REJECTED = 'rejected',
}

/**
 * An org-level player profile. `userId` is nullable because many players
 * (esp. amateur/local tournaments) won't have their own login account.
 */
@Entity({ name: 'players' })
export class Player {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'user_id' })
  user: User | null;

  @Column({ name: 'full_name', type: 'varchar', length: 255 })
  fullName: string;

  @Column({ type: 'date', nullable: true })
  dob: string | null;

  // --- Personal information (free-text, deliberately not enums, to avoid being prescriptive) ---

  @Column({ type: 'varchar', length: 20, nullable: true })
  gender: string | null;

  @Column({ type: 'varchar', length: 32, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  email: string | null;

  @Column({ type: 'text', nullable: true })
  address: string | null;

  @Column({ type: 'enum', enum: PlayerRole })
  role: PlayerRole;

  @Column({ name: 'batting_style', type: 'varchar', length: 50, nullable: true })
  battingStyle: string | null;

  @Column({ name: 'bowling_style', type: 'varchar', length: 50, nullable: true })
  bowlingStyle: string | null;

  /**
   * Free-text experience description (e.g. "5 years club cricket"),
   * deliberately not a structured years-count — registrations in the wild
   * describe experience in prose ("played 2 seasons + district trials")
   * more often than a clean integer, and a text field never forces a lossy
   * conversion at intake.
   */
  @Column({ type: 'text', nullable: true })
  experience: string | null;

  /** Preferred batting order slot or fielding position — free text. */
  @Column({ name: 'preferred_position', type: 'varchar', length: 100, nullable: true })
  preferredPosition: string | null;

  @Column({ name: 'photo_url', type: 'varchar', length: 512, nullable: true })
  photoUrl: string | null;

  @Column({ name: 'id_document_url', type: 'varchar', length: 512, nullable: true })
  idDocumentUrl: string | null;

  /** Proof-of-address document (utility bill, etc.) — same pattern as idDocumentUrl. */
  @Column({ name: 'address_proof_url', type: 'varchar', length: 512, nullable: true })
  addressProofUrl: string | null;

  /** Zero-to-many other supporting documents (certificates, prior-team letters, etc.). */
  @Column({ name: 'other_document_urls', type: 'text', array: true, nullable: true })
  otherDocumentUrls: string[] | null;

  @Column({ name: 'age_category', type: 'varchar', length: 50, nullable: true })
  ageCategory: string | null;

  /**
   * Free-text prior teams/tournaments/statistics summary. Also serves as
   * the "previous teams" field from the registration spec — a genuinely
   * separate structured `previousTeams` column would just duplicate this,
   * so it isn't added.
   */
  @Column({ name: 'previous_stats_notes', type: 'text', nullable: true })
  previousStatsNotes: string | null;

  /**
   * @deprecated Superseded by the three granular
   * isAvailableFor{Tournaments,Matches,Practice} flags below. Kept
   * (not removed) because the existing Flutter PlayerListTab's single
   * "toggle availability" action still reads/writes this pair — a future
   * cleanup could consolidate the two, but that's out of scope here.
   */
  @Column({ name: 'is_available', type: 'boolean', default: true })
  isAvailable: boolean;

  /** @deprecated See isAvailable. */
  @Column({ name: 'unavailability_reason', type: 'varchar', length: 255, nullable: true })
  unavailabilityReason: string | null;

  @Column({ name: 'is_available_for_tournaments', type: 'boolean', default: true })
  isAvailableForTournaments: boolean;

  @Column({ name: 'is_available_for_matches', type: 'boolean', default: true })
  isAvailableForMatches: boolean;

  @Column({ name: 'is_available_for_practice', type: 'boolean', default: true })
  isAvailableForPractice: boolean;

  @Column({
    name: 'verification_status',
    type: 'enum',
    enum: PlayerVerificationStatus,
    default: PlayerVerificationStatus.PENDING,
  })
  verificationStatus: PlayerVerificationStatus;

  @Column({ name: 'verification_note', type: 'varchar', length: 255, nullable: true })
  verificationNote: string | null;

  @Column({ name: 'rating', type: 'decimal', precision: 3, scale: 2, nullable: true })
  rating: string | null;

  @Column({ name: 'base_price', type: 'decimal', precision: 12, scale: 2, nullable: true })
  basePrice: string | null;

  @Column({
    type: 'enum',
    enum: PlayerStatus,
    default: PlayerStatus.ACTIVE,
  })
  status: PlayerStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
