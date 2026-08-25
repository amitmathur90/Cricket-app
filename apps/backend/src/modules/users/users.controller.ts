import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get the current authenticated user' })
  async me(@CurrentUser() user: AuthenticatedUser) {
    const record = await this.usersService.getById(user.userId);
    const { passwordHash: _passwordHash, ...safe } = record;
    return safe;
  }

  @Get('me/memberships')
  @ApiOperation({ summary: "List the current user's organization memberships" })
  myMemberships(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.getMemberships(user.userId);
  }
}
