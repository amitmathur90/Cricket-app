import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import * as crypto from 'crypto';
import { Repository } from 'typeorm';
import { OrgRole } from '../../common/enums/org-role.enum';
import {
  OrgMembership,
  OrgMembershipStatus,
} from '../../database/entities/org-membership.entity';
import { Organization } from '../../database/entities/organization.entity';
import { User } from '../../database/entities/user.entity';
import { CreateOrganizationDto } from './dto/create-organization.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { JoinOrganizationDto } from './dto/join-organization.dto';

// Uppercase alphanumeric, excluding visually ambiguous characters (0/O, 1/I).
const JOIN_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const JOIN_CODE_LENGTH = 8;
const JOIN_CODE_MAX_ATTEMPTS = 5;

@Injectable()
export class OrganizationsService {
  constructor(
    @InjectRepository(Organization) private readonly orgRepo: Repository<Organization>,
    @InjectRepository(OrgMembership)
    private readonly membershipRepo: Repository<OrgMembership>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
  ) {}

  async create(dto: CreateOrganizationDto, creatorUserId: string): Promise<Organization> {
    const slug = dto.slug ?? this.slugify(dto.name);

    const existing = await this.orgRepo.findOne({ where: { slug } });
    if (existing) {
      throw new ConflictException(`Organization slug "${slug}" is already taken`);
    }

    // Every org gets an auto-generated join code at creation time (M1: no
    // separate "generate code" step) — see JOIN_CODE_ALPHABET above.
    const org = await this.saveWithUniqueJoinCode(this.orgRepo.create({ name: dto.name, slug }));

    await this.membershipRepo.save(
      this.membershipRepo.create({
        organizationId: org.id,
        userId: creatorUserId,
        role: OrgRole.ORG_ADMIN,
        status: OrgMembershipStatus.ACTIVE,
      }),
    );

    return org;
  }

  /**
   * Self-service join: looks up the org by its join code and creates an
   * ACTIVE `player`-role membership for the caller. Auto-join — the code
   * itself is the access gate, no separate admin approval step at the
   * org-membership level (that gatekeeping happens per-tournament via the
   * tournament-applications review flow instead).
   */
  async join(dto: JoinOrganizationDto, userId: string): Promise<{
    organization: Pick<Organization, 'id' | 'name' | 'slug'>;
    membership: OrgMembership;
  }> {
    const org = await this.orgRepo.findOne({
      where: { joinCode: dto.joinCode.trim().toUpperCase() },
    });
    if (!org) {
      throw new NotFoundException('Invalid join code');
    }

    const existingMembership = await this.membershipRepo.findOne({
      where: { organizationId: org.id, userId },
    });
    if (existingMembership) {
      throw new ConflictException('You already have a membership in this organization');
    }

    let membership: OrgMembership;
    try {
      membership = await this.membershipRepo.save(
        this.membershipRepo.create({
          organizationId: org.id,
          userId,
          role: OrgRole.PLAYER,
          status: OrgMembershipStatus.ACTIVE,
        }),
      );
    } catch (err) {
      // Race with a concurrent join/invite for the same user+org — the
      // pre-check above can't fully close this gap, so translate the
      // DB-level conflict too (same pattern as AuthService.register).
      if ((err as { code?: string }).code === '23505') {
        throw new ConflictException('You already have a membership in this organization');
      }
      throw err;
    }

    return {
      organization: { id: org.id, name: org.name, slug: org.slug },
      membership,
    };
  }

  /** Admin-only: rotate the join code in case it leaks. */
  async regenerateJoinCode(
    organizationId: string,
    callerUserId: string,
    isSuperAdmin: boolean,
  ): Promise<Organization> {
    const org = await this.orgRepo.findOne({ where: { id: organizationId } });
    if (!org) {
      throw new NotFoundException('Organization not found');
    }

    if (!isSuperAdmin) {
      const caller = await this.assertActiveMember(organizationId, callerUserId);
      if (caller.role !== OrgRole.ORG_ADMIN) {
        throw new ForbiddenException('Only an org_admin can regenerate the join code');
      }
    }

    return this.saveWithUniqueJoinCode(org);
  }

  async findById(
    organizationId: string,
    callerUserId: string,
    isSuperAdmin: boolean,
  ): Promise<Organization> {
    const org = await this.orgRepo.findOne({ where: { id: organizationId } });
    if (!org) {
      throw new NotFoundException('Organization not found');
    }

    if (!isSuperAdmin) {
      await this.assertActiveMember(organizationId, callerUserId);
    }

    return org;
  }

  async listMembers(
    organizationId: string,
    callerUserId: string,
    isSuperAdmin: boolean,
  ): Promise<OrgMembership[]> {
    if (!isSuperAdmin) {
      await this.assertActiveMember(organizationId, callerUserId);
    }

    return this.membershipRepo.find({
      where: { organizationId },
      relations: ['user'],
      order: { createdAt: 'ASC' },
    });
  }

  async inviteMember(
    organizationId: string,
    dto: InviteMemberDto,
    callerUserId: string,
    isSuperAdmin: boolean,
  ): Promise<OrgMembership> {
    if (!isSuperAdmin) {
      const caller = await this.assertActiveMember(organizationId, callerUserId);
      if (caller.role !== OrgRole.ORG_ADMIN) {
        throw new ForbiddenException('Only an org_admin can invite members');
      }
    }

    const invitee = await this.userRepo.findOne({ where: { email: dto.email } });
    if (!invitee) {
      throw new NotFoundException(
        'No user account found for this email — ask them to register first',
      );
    }

    const existingMembership = await this.membershipRepo.findOne({
      where: { organizationId, userId: invitee.id },
    });
    if (existingMembership) {
      throw new ConflictException('This user is already a member (or invited) of this organization');
    }

    return this.membershipRepo.save(
      this.membershipRepo.create({
        organizationId,
        userId: invitee.id,
        role: dto.role,
        status: OrgMembershipStatus.INVITED,
        invitedByUserId: callerUserId,
      }),
    );
  }

  private async assertActiveMember(
    organizationId: string,
    userId: string,
  ): Promise<OrgMembership> {
    const membership = await this.membershipRepo.findOne({
      where: { organizationId, userId, status: OrgMembershipStatus.ACTIVE },
    });
    if (!membership) {
      throw new ForbiddenException('Not an active member of this organization');
    }
    return membership;
  }

  private slugify(name: string): string {
    return name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '');
  }

  private generateJoinCode(): string {
    const bytes = crypto.randomBytes(JOIN_CODE_LENGTH);
    let code = '';
    for (let i = 0; i < JOIN_CODE_LENGTH; i++) {
      code += JOIN_CODE_ALPHABET[bytes[i] % JOIN_CODE_ALPHABET.length];
    }
    return code;
  }

  /**
   * Assigns a fresh join code to `org` and saves it, retrying on a rare
   * unique-constraint collision. Used both for initial org creation and
   * for explicit regeneration.
   */
  private async saveWithUniqueJoinCode(org: Organization): Promise<Organization> {
    for (let attempt = 0; attempt < JOIN_CODE_MAX_ATTEMPTS; attempt++) {
      org.joinCode = this.generateJoinCode();
      try {
        return await this.orgRepo.save(org);
      } catch (err) {
        const isLastAttempt = attempt === JOIN_CODE_MAX_ATTEMPTS - 1;
        if ((err as { code?: string }).code === '23505' && !isLastAttempt) {
          continue;
        }
        throw err;
      }
    }
    // Unreachable — the loop above always returns or throws.
    throw new ConflictException('Could not allocate a unique join code, please retry');
  }
}
