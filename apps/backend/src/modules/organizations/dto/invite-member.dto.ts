import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsEnum } from 'class-validator';
import { OrgRole } from '../../../common/enums/org-role.enum';

export class InviteMemberDto {
  @ApiProperty({ example: 'scorer@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ enum: OrgRole, example: OrgRole.SCORER })
  @IsEnum(OrgRole)
  role: OrgRole;
}
