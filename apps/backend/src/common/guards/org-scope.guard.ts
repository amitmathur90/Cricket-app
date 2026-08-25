import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Request } from 'express';
import { AuthenticatedUser } from '../types/authenticated-user';

/**
 * Asserts that any `:organizationId` route param, or `organizationId` field
 * in the request body, matches the caller's active-org JWT claim. A
 * super_admin bypasses this check (they can act across orgs). Must run
 * after JwtAuthGuard so `req.user` is already populated.
 */
@Injectable()
export class OrgScopeGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request & { user?: AuthenticatedUser }>();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('Missing authenticated user context');
    }

    if (user.isSuperAdmin) {
      return true;
    }

    const paramOrgId = request.params?.organizationId;
    const bodyOrgId = (request.body as Record<string, unknown> | undefined)?.organizationId as
      | string
      | undefined;

    const requestedOrgId = paramOrgId ?? bodyOrgId;

    if (!requestedOrgId) {
      // No org identifier present on the request — nothing to scope-check
      // here (route may rely solely on RolesGuard / service-level scoping).
      return true;
    }

    if (!user.activeOrgId || requestedOrgId !== user.activeOrgId) {
      throw new ForbiddenException('Organization scope mismatch');
    }

    return true;
  }
}
