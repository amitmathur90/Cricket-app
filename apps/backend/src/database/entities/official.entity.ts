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

export enum OfficialRole {
  UMPIRE = 'umpire',
  SCORER = 'scorer',
  MATCH_REFEREE = 'match_referee',
}

export enum OfficialStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
}

/**
 * A single org-level table covering umpires, scorers, and match referees via
 * `role`, rather than three near-identical tables — matches how the spec
 * groups them under one "Umpire & Officials" heading. Same lightweight shape
 * as `Coach`/`Venue`: no login/user account. See `Match.umpireOfficialId` /
 * `scorerOfficialId` / `matchRefereeOfficialId` for how an official gets
 * assigned to a match (alongside the legacy free-text `umpireName`/`scorerName`).
 */
@Entity({ name: 'officials' })
export class Official {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Column({ name: 'full_name', type: 'varchar', length: 255 })
  fullName: string;

  @Column({ type: 'enum', enum: OfficialRole })
  role: OfficialRole;

  @Column({ type: 'varchar', length: 32, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  email: string | null;

  @Column({ name: 'photo_url', type: 'varchar', length: 512, nullable: true })
  photoUrl: string | null;

  @Column({ type: 'enum', enum: OfficialStatus, default: OfficialStatus.ACTIVE })
  status: OfficialStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
