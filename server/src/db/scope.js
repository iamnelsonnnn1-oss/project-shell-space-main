export class ForbiddenError extends Error {
  constructor(message = 'forbidden') {
    super(message);
    this.name = 'ForbiddenError';
    this.statusCode = 403;
  }
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Run `fn(client, { userId, workspaceId, role })` in a transaction whose row-level security
 * context is set to this user and workspace. Membership is verified in the database; a caller
 * who is not a member gets ForbiddenError and no work is done.
 * `pool` is any pg.Pool-compatible object. The pool MUST connect as the non-owner `shellspace_app` role.
 */
export async function withWorkspaceScope(pool, { userId, workspaceId }, fn) {
  if (!UUID.test(userId) || !UUID.test(workspaceId)) throw new ForbiddenError('invalid scope');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT set_config('app.user_id', $1, true), set_config('app.workspace_id', $2, true)", [userId, workspaceId]);
    const { rows } = await client.query('SELECT role FROM memberships WHERE user_id = $1 AND workspace_id = $2', [userId, workspaceId]);
    if (rows.length === 0) throw new ForbiddenError('not a member of this workspace');
    const result = await fn(client, { userId, workspaceId, role: rows[0].role });
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}
