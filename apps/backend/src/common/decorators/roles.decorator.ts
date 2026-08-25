import { SetMetadata } from '@nestjs/common';
import { OrgRole } from '../enums/org-role.enum';

export const ROLES_KEY = 'roles';

/**
 * Marks a route as requiring at least one of the given org roles. Checked by
 * RolesGuard against the caller's active-org role using the hierarchy in
 * org-role.enum.ts (a higher role satisfies a lower requirement). A
 * super_admin bypasses this check entirely.
 */
export const Roles = (...roles: OrgRole[]) => SetMetadata(ROLES_KEY, roles);
