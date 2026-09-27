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
import { RequestMobileLoginOtpDto } from './dto/request-mobile-login-otp.dto';
import { RequestPasswordResetDto } from './dto/request-password-reset.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { SelectOrgDto } from './dto/select-org.dto';
import { VerifyMobileLoginOtpDto } from './dto/verify-mobile-login-otp.dto';
import { VerifyPasswordResetOtpDto } from './dto/verify-password-reset-otp.dto';

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

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('forgot-password')
  @ApiOperation({
    summary:
      'Step 1 of password reset — emails a 6-digit OTP to the account matching this email/phone. ' +
      'Always returns the same generic message, whether or not a matching account exists.',
  })
  forgotPassword(@Body() dto: RequestPasswordResetDto) {
    return this.authService.requestPasswordReset(dto.identifier);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('forgot-password/verify-otp')
  @ApiOperation({
    summary: 'Step 2 of password reset — verifies the OTP and returns a resetToken for step 3',
  })
  verifyPasswordResetOtp(@Body() dto: VerifyPasswordResetOtpDto) {
    return this.authService.verifyPasswordResetOtp(dto.identifier, dto.otp);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('reset-password')
  @ApiOperation({ summary: 'Step 3 of password reset — sets a new password using the verified resetToken' })
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(dto.resetToken, dto.newPassword);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('login/mobile/request-otp')
  @ApiOperation({
    summary:
      'Step 1 of "Login with mobile OTP" — texts a 4-digit OTP (via Renflair) to the account matching ' +
      'this phone number. Always returns the same generic message, whether or not a matching account exists. ' +
      'If DEV_OTP_FALLBACK=true and the SMS send fails, the response also includes a devOtp field with the ' +
      'code — an explicit opt-in testing aid, off by default; see AuthService.requestMobileLoginOtp.',
  })
  requestMobileLoginOtp(@Body() dto: RequestMobileLoginOtpDto) {
    return this.authService.requestMobileLoginOtp(dto.phone);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('login/mobile/verify-otp')
  @ApiOperation({
    summary:
      'Step 2 of "Login with mobile OTP" — verifies the OTP and, on success, issues real access/refresh ' +
      'tokens (same shape as POST /auth/login).',
  })
  verifyMobileLoginOtp(@Body() dto: VerifyMobileLoginOtpDto) {
    return this.authService.verifyMobileLoginOtp(dto.phone, dto.otp);
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
