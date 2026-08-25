import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ORG_ROLE_HIERARCHY, OrgRole } from '../enums/org-role.enum';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { AuthenticatedUser } from '../types/authenticated-user';

/**
 * Reads @Roles(...) metadata and checks it against the caller's active-org
 * role using ORG_ROLE_HIERARCHY: a role earlier in the hierarchy (higher
 * privilege) satisfies a requirement for a role later in it. `super_admin`
 * (a global flag, not an OrgRole) always passes. Must run after
 * JwtAuthGuard.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<OrgRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) {
      // No @Roles() on this route — any authenticated (and org-scoped) user
      // may access it.
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const user: AuthenticatedUser | undefined = request.user;

    if (!user) {
      throw new ForbiddenException('Missing authenticated user context');
    }

    if (user.isSuperAdmin) {
      return true;
    }

    if (!user.role) {
      throw new ForbiddenException('No active organization role selected');
    }

    const userRank = ORG_ROLE_HIERARCHY.indexOf(user.role);

    const satisfied = requiredRoles.some((required) => {
      const requiredRank = ORG_ROLE_HIERARCHY.indexOf(required);
      // Lower index = higher privilege. A user's rank at or above (<=) the
      // required rank satisfies the requirement.
      return userRank !== -1 && userRank <= requiredRank;
    });

    if (!satisfied) {
      throw new ForbiddenException('Insufficient role for this action');
    }

    return true;
  }
}
