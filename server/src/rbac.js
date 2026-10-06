import { ForbiddenError } from './db/scope.js';

const RANK = { user: 1, admin: 2 };

/** Application-layer check. PostgreSQL row-level security enforces the same rule independently. */
export function requireRole(scope, minimum) {
  if ((RANK[scope.role] ?? 0) < RANK[minimum]) {
    throw new ForbiddenError(`requires ${minimum} role`);
  }
}
