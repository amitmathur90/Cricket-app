import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MobileLoginOtp } from '../../database/entities/mobile-login-otp.entity';
import { OrgMembership } from '../../database/entities/org-membership.entity';
import { PasswordResetToken } from '../../database/entities/password-reset-token.entity';
import { RefreshToken } from '../../database/entities/refresh-token.entity';
import { User } from '../../database/entities/user.entity';
import { MailModule } from '../mail/mail.module';
import { SmsModule } from '../sms/sms.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, OrgMembership, RefreshToken, PasswordResetToken, MobileLoginOtp]),
    MailModule,
    SmsModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('jwt.accessSecret') as string,
        signOptions: { expiresIn: configService.get<string>('jwt.accessTtl') },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
