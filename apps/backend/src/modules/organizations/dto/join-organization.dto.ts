import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class JoinOrganizationDto {
  @ApiProperty({ example: 'AB3XQZ9K', description: "The organization's join code" })
  @IsString()
  @IsNotEmpty()
  joinCode: string;
}
