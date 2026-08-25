/** Mirrors apps/mobile/lib/features/organizations/data/models/organization.dart. */
export interface Organization {
  id: string
  name: string
  slug: string
  logoUrl: string | null
  subscriptionTier: string
  status: string
  /** Present on GET /organizations/:id; null on the partial object embedded
   * elsewhere (e.g. join responses). */
  joinCode: string | null
}

/** Server-enforced role hierarchy, highest to lowest privilege. Mirrors
 * apps/backend/src/common/enums/org-role.enum.ts. `super_admin` is a
 * separate global user flag (SafeUser.isSuperAdmin), not a member of this
 * enum — it always passes RolesGuard regardless of org role. */
export type OrgRole =
  | 'org_admin'
  | 'tournament_admin'
  | 'team_owner'
  | 'scorer'
  | 'umpire'
  | 'player'
  | 'viewer'

/** Lower index = higher privilege. Mirrors ORG_ROLE_HIERARCHY server-side —
 * used only for client-side nav hiding (UX), never as a real security
 * boundary; RolesGuard is the actual enforcement point. */
export const ORG_ROLE_HIERARCHY: OrgRole[] = [
  'org_admin',
  'tournament_admin',
  'team_owner',
  'scorer',
  'umpire',
  'player',
  'viewer',
]

export function roleAtOrAbove(currentRole: OrgRole | null, minRole: OrgRole, isSuperAdmin: boolean): boolean {
  if (isSuperAdmin) return true
  if (!currentRole) return false
  return ORG_ROLE_HIERARCHY.indexOf(currentRole) <= ORG_ROLE_HIERARCHY.indexOf(minRole)
}

/** Mirrors apps/mobile/lib/features/organizations/data/models/org_membership.dart —
 * GET /users/me/memberships, with `organization` eager-loaded. */
export interface OrgMembership {
  id: string
  organizationId: string
  userId: string
  role: OrgRole
  /** One of 'invited' | 'active' | 'removed'. */
  status: string
  organization: Organization | null
}
