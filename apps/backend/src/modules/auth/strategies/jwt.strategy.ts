import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { OrgRole } from '../../../common/enums/org-role.enum';
import { AuthenticatedUser } from '../../../common/types/authenticated-user';

export interface JwtAccessPayload {
  sub: string;
  isSuperAdmin: boolean;
  activeOrgId: string | null;
  role: OrgRole | null;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('jwt.accessSecret') as string,
    });
  }

  validate(payload: JwtAccessPayload): AuthenticatedUser {
    return {
      userId: payload.sub,
      isSuperAdmin: payload.isSuperAdmin,
      activeOrgId: payload.activeOrgId ?? null,
      role: payload.role ?? null,
    };
  }
}
