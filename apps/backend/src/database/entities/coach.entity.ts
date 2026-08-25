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

export enum CoachStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
}

/**
 * A lightweight org-level coach profile — deliberately no login/user
 * account, mirroring how `Player.userId` is nullable for players without
 * their own account. This is not a staff/HR module; just enough identity
 * (name, contact, specialization, photo) to assign a named coach to a
 * practice session.
 */
@Entity({ name: 'coaches' })
export class Coach {
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

  @Column({ type: 'varchar', length: 32, nullable: true })
  phone: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  email: string | null;

  /** Free text, e.g. "Batting coach", "Fitness trainer" — deliberately not an enum. */
  @Column({ type: 'varchar', length: 100, nullable: true })
  specialization: string | null;

  @Column({ name: 'photo_url', type: 'varchar', length: 512, nullable: true })
  photoUrl: string | null;

  @Column({ type: 'enum', enum: CoachStatus, default: CoachStatus.ACTIVE })
  status: CoachStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
