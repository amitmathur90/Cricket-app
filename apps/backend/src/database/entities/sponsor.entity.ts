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

export enum SponsorStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
}

/**
 * A lightweight org-level sponsor profile, same shape as `Coach`/`Venue`/
 * `Official`. The `visibleOn*` flags are honest configuration metadata for
 * display surfaces the app doesn't render yet (tournament website, social
 * media, scoreboard overlay) — storing them now means the org can configure
 * sponsor visibility ahead of those surfaces existing. `visibleOnApp` is the
 * one flag that's immediately actionable (a future Flutter screen could show
 * sponsor logos where it's true). This module does NOT build any of that
 * display wiring — it only stores the flags.
 */
@Entity({ name: 'sponsors' })
export class Sponsor {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ name: 'company_name', type: 'varchar', length: 255 })
  companyName: string;

  @Column({ name: 'logo_url', type: 'varchar', length: 512, nullable: true })
  logoUrl: string | null;

  /** Free text, e.g. "Title Sponsor", "Gold", "Silver" — deliberately not an enum. */
  @Column({ name: 'package_name', type: 'varchar', length: 100, nullable: true })
  packageName: string | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  amount: string | null;

  @Column({ name: 'contract_start_date', type: 'date', nullable: true })
  contractStartDate: string | null;

  @Column({ name: 'contract_end_date', type: 'date', nullable: true })
  contractEndDate: string | null;

  @Column({ type: 'enum', enum: SponsorStatus, default: SponsorStatus.ACTIVE })
  status: SponsorStatus;

  // --- Display-surface visibility configuration (metadata only — see class doc) ---

  @Column({ name: 'visible_on_website', type: 'boolean', default: false })
  visibleOnWebsite: boolean;

  @Column({ name: 'visible_on_app', type: 'boolean', default: false })
  visibleOnApp: boolean;

  @Column({ name: 'visible_on_match_screen', type: 'boolean', default: false })
  visibleOnMatchScreen: boolean;

  @Column({ name: 'visible_on_scoreboard', type: 'boolean', default: false })
  visibleOnScoreboard: boolean;

  @Column({ name: 'visible_on_social_media', type: 'boolean', default: false })
  visibleOnSocialMedia: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
