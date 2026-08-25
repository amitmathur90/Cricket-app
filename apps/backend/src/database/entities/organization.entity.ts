import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

export enum OrganizationStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
}

@Entity({ name: 'organizations' })
export class Organization {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'varchar', length: 255, unique: true })
  slug: string;

  @Column({ name: 'logo_url', type: 'varchar', length: 512, nullable: true })
  logoUrl: string | null;

  @Column({ name: 'subscription_tier', type: 'varchar', length: 50, default: 'free' })
  subscriptionTier: string;

  /**
   * Short shareable code (8-char, uppercase alphanumeric, ambiguous
   * characters like 0/O/1/I excluded) that lets a user self-join this org
   * as a `player`-role member via POST /organizations/join. Generated
   * automatically on org creation (see OrganizationsService.create) and
   * rotatable via POST /organizations/:organizationId/join-code/regenerate.
   */
  @Column({ name: 'join_code', type: 'varchar', length: 8, unique: true })
  joinCode: string;

  @Column({
    type: 'enum',
    enum: OrganizationStatus,
    default: OrganizationStatus.ACTIVE,
  })
  status: OrganizationStatus;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
