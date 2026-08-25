import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../../common/types/authenticated-user';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';
import { SelectOrgDto } from './dto/select-org.dto';

@ApiTags('auth')
@UseGuards(JwtAuthGuard)
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Create a new user account' })
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('login')
  @ApiOperation({ summary: 'Authenticate with email/password' })
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('refresh')
  @ApiOperation({ summary: 'Rotate a refresh token for a new access/refresh token pair' })
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  // Intentionally NOT @Public(): selecting an org requires knowing who is
  // asking (req.user.userId from a valid, already-issued access token), so
  // it stays behind JwtAuthGuard — see auth.service.ts / AuthModule notes.
  @HttpCode(HttpStatus.OK)
  @Post('select-org')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mint a new access token scoped to a specific organization' })
  selectOrg(@CurrentUser() user: AuthenticatedUser, @Body() dto: SelectOrgDto) {
    return this.authService.selectOrg(user.userId, dto.organizationId);
  }
}
