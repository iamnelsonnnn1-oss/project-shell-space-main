import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { withWorkspaceScope, ForbiddenError } from '../src/db/scope.js';
import { requireRole } from '../src/rbac.js';
import { unconfiguredAuth, unconfiguredOtp, unconfiguredVideo, unconfiguredKeys } from '../src/interfaces/index.js';
import { NotConfiguredError } from '../src/errors.js';

test('health endpoint', async () => {
  const res = await buildApp().inject('/api/health');
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.json(), { status: 'ok' });
});

test('every undecided provider fails closed', async () => {
  for (const [p, fn] of [[unconfiguredAuth, 'authenticate'], [unconfiguredOtp, 'send'], [unconfiguredOtp, 'verify'], [unconfiguredVideo, 'createRoom'], [unconfiguredKeys, 'encrypt'], [unconfiguredKeys, 'decrypt']]) {
    await assert.rejects(p[fn](), NotConfiguredError);
  }
});

test('config only allows a loopback bind', () => {
  assert.throws(() => loadConfig({ HOST: '0.0.0.0', DATABASE_URL: 'postgres://u:p@127.0.0.1/db' }));
  assert.equal(loadConfig({ DATABASE_URL: 'postgres://u:p@127.0.0.1/db' }).HOST, '127.0.0.1');
});

const U = '00000000-0000-4000-8000-00000000000a';
const W = '10000000-0000-4000-8000-000000000001';
function fakePool(role) {
  const log = [];
  const client = {
    query: async (sql) => { log.push(sql.split(' ')[0]); return { rows: sql.startsWith('SELECT role') ? (role ? [{ role }] : []) : [] }; },
    release: () => log.push('release'),
  };
  return { pool: { connect: async () => client }, log };
}

test('scope helper rejects non-members without running the callback', async () => {
  const { pool, log } = fakePool(null);
  let ran = false;
  await assert.rejects(withWorkspaceScope(pool, { userId: U, workspaceId: W }, async () => { ran = true; }), ForbiddenError);
  assert.equal(ran, false);
  assert.ok(log.includes('ROLLBACK') && log.includes('release'));
});

test('scope helper rejects malformed ids and commits on success', async () => {
  await assert.rejects(withWorkspaceScope(fakePool('user').pool, { userId: "x'; --", workspaceId: W }, async () => {}), ForbiddenError);
  const { pool, log } = fakePool('admin');
  const scope = await withWorkspaceScope(pool, { userId: U, workspaceId: W }, async (_c, s) => s);
  assert.equal(scope.role, 'admin');
  assert.ok(log.includes('COMMIT'));
});

test('rbac: admin-only actions reject plain users', () => {
  assert.throws(() => requireRole({ role: 'user' }, 'admin'), ForbiddenError);
  requireRole({ role: 'admin' }, 'admin');
});
