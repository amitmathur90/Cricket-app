import { FindOptionsWhere, ObjectLiteral, Repository } from 'typeorm';

/**
 * Tenant-scoping convention (M1): every service method that reads/writes
 * tenant data MUST take `organizationId` as its first argument and fold it
 * into the query `where` clause, so an unscoped query is structurally
 * awkward to write (you'd have to deliberately omit the parameter).
 *
 * This file is intentionally NOT a full generic base repository/service
 * class — TypeORM entities in this codebase have a plain `organizationId`
 * column, and services call these small helpers directly rather than
 * inheriting a heavy abstraction. Keep it simple; revisit only if the
 * duplication across services actually becomes a problem.
 *
 * Usage:
 *   findOrgScoped(this.tournamentRepo, organizationId, { id })
 */
export function orgScopedWhere<T extends ObjectLiteral>(
  organizationId: string,
  where: FindOptionsWhere<T> = {} as FindOptionsWhere<T>,
): FindOptionsWhere<T> {
  return { ...where, organizationId } as FindOptionsWhere<T>;
}

export async function findOneOrgScoped<T extends ObjectLiteral>(
  repository: Repository<T>,
  organizationId: string,
  where: FindOptionsWhere<T>,
): Promise<T | null> {
  return repository.findOne({ where: orgScopedWhere<T>(organizationId, where) });
}

export async function findManyOrgScoped<T extends ObjectLiteral>(
  repository: Repository<T>,
  organizationId: string,
  where: FindOptionsWhere<T> = {} as FindOptionsWhere<T>,
): Promise<T[]> {
  return repository.find({ where: orgScopedWhere<T>(organizationId, where) });
}
