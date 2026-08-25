import { OrgRole } from '../enums/org-role.enum';

/**
 * Shape of `req.user`, populated by JwtAuthGuard from the validated access
 * token payload. `activeOrgId`/`role` are null until the user calls
 * POST /auth/select-org (or registers/logs in with a single membership,
 * which auto-selects it).
 */
export interface AuthenticatedUser {
  userId: string;
  isSuperAdmin: boolean;
  activeOrgId: string | null;
  role: OrgRole | null;
}
