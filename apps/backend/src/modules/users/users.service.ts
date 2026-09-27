import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { OrgMembership } from '../../database/entities/org-membership.entity';
import { User } from '../../database/entities/user.entity';
import { SmsService } from '../sms/sms.service';
import { UpdateMeDto } from './dto/update-me.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(OrgMembership)
    private readonly membershipRepo: Repository<OrgMembership>,
  ) {}

  async getById(userId: string): Promise<User> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async updateMe(userId: string, dto: UpdateMeDto): Promise<User> {
    const user = await this.getById(userId);
    if (dto.fullName !== undefined) user.fullName = dto.fullName;
    if (dto.phone !== undefined) user.phone = SmsService.normalizePhone(dto.phone);
    return this.userRepo.save(user);
  }

  async getMemberships(userId: string): Promise<OrgMembership[]> {
    return this.membershipRepo.find({
      where: { userId },
      relations: ['organization'],
      order: { createdAt: 'ASC' },
    });
  }
}
