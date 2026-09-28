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

export enum TournamentFormat {
  T20 = 't20',
  ODI = 'odi',
  T10 = 't10',
  CUSTOM = 'custom',
}

export enum TournamentStatus {
  DRAFT = 'draft',
  UPCOMING = 'upcoming',
  LIVE = 'live',
  COMPLETED = 'completed',
}

@Entity({ name: 'tournaments' })
export class Tournament {
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

  @Column({ type: 'enum', enum: TournamentFormat })
  format: TournamentFormat;

  @Column({ name: 'start_date', type: 'date' })
  startDate: string;

  @Column({ name: 'end_date', type: 'date' })
  endDate: string;

  @Column({
    type: 'enum',
    enum: TournamentStatus,
    default: TournamentStatus.DRAFT,
  })
  status: TournamentStatus;

  @Column({ name: 'auction_enabled', type: 'boolean', default: false })
  auctionEnabled: boolean;

  /**
   * Marks the one hidden, auto-created tournament per organization that
   * backs "Quick Match" (start a match between two ad-hoc teams with no
   * tournament setup — see QuickMatchService). Never shown in tournament
   * lists/management UI; exists purely so every existing tournament-scoped
   * piece (team registration, rosters, lineups, scoring) works unchanged
   * for quick matches too, with zero duplicated infrastructure.
   */
  @Column({ name: 'is_quick_match_pool', type: 'boolean', default: false })
  isQuickMatchPool: boolean;

  // --- Basic info ---

  @Column({ name: 'logo_url', type: 'varchar', length: 512, nullable: true })
  logoUrl: string | null;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ name: 'organizer_name', type: 'varchar', length: 255, nullable: true })
  organizerName: string | null;

  @Column({ name: 'contact_email', type: 'varchar', length: 255, nullable: true })
  contactEmail: string | null;

  @Column({ name: 'contact_phone', type: 'varchar', length: 32, nullable: true })
  contactPhone: string | null;

  // --- Tournament details ---

  @Column({ type: 'varchar', length: 255, nullable: true })
  location: string | null;

  @Column({ name: 'number_of_teams', type: 'int', nullable: true })
  numberOfTeams: number | null;

  @Column({ name: 'max_players_per_team', type: 'int', nullable: true })
  maxPlayersPerTeam: number | null;

  // --- Rules ---

  @Column({ name: 'tournament_rules', type: 'text', nullable: true })
  tournamentRules: string | null;

  @Column({ name: 'match_rules', type: 'text', nullable: true })
  matchRules: string | null;

  /**
   * Free-text points system description (e.g. "2 pts win, 1 pt tie, 0 pt
   * loss"). A future milestone may turn this into a structured points-config
   * object; deliberately kept as free text for now.
   */
  @Column({ name: 'points_system', type: 'text', nullable: true })
  pointsSystem: string | null;

  @Column({ name: 'tie_breaker_rules', type: 'text', nullable: true })
  tieBreakerRules: string | null;

  // --- Registration ---

  @Column({ name: 'registration_opens_at', type: 'date', nullable: true })
  registrationOpensAt: string | null;

  @Column({ name: 'registration_closes_at', type: 'date', nullable: true })
  registrationClosesAt: string | null;

  @Column({
    name: 'player_registration_fee',
    type: 'decimal',
    precision: 12,
    scale: 2,
    nullable: true,
  })
  playerRegistrationFee: string | null;

  @Column({
    name: 'team_registration_fee',
    type: 'decimal',
    precision: 12,
    scale: 2,
    nullable: true,
  })
  teamRegistrationFee: string | null;

  @Column({ name: 'created_by_user_id', type: 'uuid' })
  createdByUserId: string;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'created_by_user_id' })
  createdByUser: User;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
