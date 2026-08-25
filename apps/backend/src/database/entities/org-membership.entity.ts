import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';
import { OrgRole } from '../../common/enums/org-role.enum';
import { Organization } from './organization.entity';
import { User } from './user.entity';

export enum OrgMembershipStatus {
  INVITED = 'invited',
  ACTIVE = 'active',
  REMOVED = 'removed',
}

/**
 * The join table between users and organizations — this is where
 * multi-tenant RBAC is actually enforced (see OrgScopeGuard/RolesGuard).
 */
@Entity({ name: 'org_memberships' })
@Unique('uq_org_membership_org_user', ['organizationId', 'userId'])
export class OrgMembership {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'organization_id', type: 'uuid' })
  organizationId: string;

  @ManyToOne(() => Organization, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'organization_id' })
  organization: Organization;

  @Index()
  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'enum', enum: OrgRole })
  role: OrgRole;

  @Column({
    type: 'enum',
    enum: OrgMembershipStatus,
    default: OrgMembershipStatus.ACTIVE,
  })
  status: OrgMembershipStatus;

  @Column({ name: 'invited_by_user_id', type: 'uuid', nullable: true })
  invitedByUserId: string | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'invited_by_user_id' })
  invitedByUser: User | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
