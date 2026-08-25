/**
 * Roles a user can hold within a single organization (an `org_memberships` row).
 * `super_admin` is intentionally NOT part of this enum — it is a global flag
 * (`users.is_super_admin`) that bypasses org scoping entirely, rather than a
 * per-org role. See RolesGuard for how the two interact.
 */
export enum OrgRole {
  ORG_ADMIN = 'org_admin',
  TOURNAMENT_ADMIN = 'tournament_admin',
  TEAM_OWNER = 'team_owner',
  SCORER = 'scorer',
  UMPIRE = 'umpire',
  PLAYER = 'player',
  VIEWER = 'viewer',
}

/**
 * Role hierarchy from highest to lowest privilege. A user holding a role that
 * appears earlier in this list satisfies any `@Roles()` requirement for a
 * role that appears later. `super_admin` sits conceptually above all of
 * these (see RolesGuard) but is not itself an OrgRole value.
 */
export const ORG_ROLE_HIERARCHY: OrgRole[] = [
  OrgRole.ORG_ADMIN,
  OrgRole.TOURNAMENT_ADMIN,
  OrgRole.TEAM_OWNER,
  OrgRole.SCORER,
  OrgRole.UMPIRE,
  OrgRole.PLAYER,
  OrgRole.VIEWER,
];
