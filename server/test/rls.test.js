import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const A = '00000000-0000-4000-8000-00000000000a'; // admin of W1
const B = '00000000-0000-4000-8000-00000000000b'; // member of W1
const C = '00000000-0000-4000-8000-00000000000c'; // member of W2 only
const W1 = '10000000-0000-4000-8000-000000000001';
const W2 = '10000000-0000-4000-8000-000000000002';
const CH1 = '20000000-0000-4000-8000-000000000001';
const CH2 = '20000000-0000-4000-8000-000000000002';

let db;
// Run a statement as the API role with a given request context.
async function as(userId, workspaceId, sql, params = []) {
  await db.exec('BEGIN');
  try {
    await db.exec('SET LOCAL ROLE shellspace_app');
    await db.query("SELECT set_config('app.user_id', $1, true), set_config('app.workspace_id', $2, true)", [userId ?? '', workspaceId ?? '']);
    const res = await db.query(sql, params);
    await db.exec('COMMIT');
    return res.rows;
  } catch (e) {
    await db.exec('ROLLBACK');
    throw e;
  }
}

before(async () => {
  db = new PGlite();
  await db.exec('CREATE ROLE shellspace_app NOLOGIN');
  await db.exec(await readFile(new URL('../migrations/0001_init.sql', import.meta.url), 'utf8'));
  await db.exec(`
    INSERT INTO users (id, email, full_name) VALUES ('${A}','a@x.io','A'),('${B}','b@x.io','B'),('${C}','c@x.io','C');
    INSERT INTO workspaces (id, name, slug) VALUES ('${W1}','One','one'),('${W2}','Two','two');
    INSERT INTO memberships (user_id, workspace_id, role) VALUES ('${A}','${W1}','admin'),('${B}','${W1}','user'),('${C}','${W2}','admin');
    INSERT INTO channels (id, workspace_id, name, created_by) VALUES ('${CH1}','${W1}','general','${A}'),('${CH2}','${W2}','general','${C}');
    INSERT INTO messages (workspace_id, channel_id, author_id, author_name, body_ciphertext, encryption_meta)
      VALUES ('${W1}','${CH1}','${A}','A','\\x00','{}'),('${W2}','${CH2}','${C}','C','\\x00','{}');
  `);
});

test('a member sees only their workspace rows', async () => {
  assert.equal((await as(B, W1, 'SELECT * FROM messages')).length, 1);
  assert.equal((await as(C, W2, 'SELECT * FROM messages')).length, 1);
});

test('naming another workspace does not grant access', async () => {
  assert.equal((await as(B, W2, 'SELECT * FROM messages')).length, 0);
  assert.equal((await as(B, W2, 'SELECT * FROM channels')).length, 0);
});

test('no request context means no rows', async () => {
  assert.equal((await as(null, null, 'SELECT * FROM messages')).length, 0);
  assert.equal((await as(null, null, 'SELECT * FROM workspaces')).length, 0);
});

test('only admins can create channels', async () => {
  await assert.rejects(as(B, W1, "INSERT INTO channels (workspace_id, name, created_by) VALUES ($1,'x',$2)", [W1, B]));
  const rows = await as(A, W1, "INSERT INTO channels (workspace_id, name, created_by) VALUES ($1,'ok',$2) RETURNING id", [W1, A]);
  assert.equal(rows.length, 1);
});

test('messages must be authored by the caller and stay in scope', async () => {
  const ins = "INSERT INTO messages (workspace_id, channel_id, author_id, author_name, body_ciphertext, encryption_meta) VALUES ($1,$2,$3,'n','\\x01','{}')";
  await assert.rejects(as(B, W1, ins, [W1, CH1, A]), /row-level security/);
  await assert.rejects(as(B, W2, ins, [W2, CH2, B]), /row-level security/);
  await as(B, W1, ins, [W1, CH1, B]);
});

test('composite keys block cross-workspace parents', async () => {
  await assert.rejects(
    db.query("INSERT INTO messages (workspace_id, channel_id, author_id, author_name, body_ciphertext, encryption_meta) VALUES ($1,$2,$3,'n','\\x01','{}')", [W1, CH2, A]),
    /foreign key/i,
  );
});

test('content columns are ciphertext only (no plaintext body column)', async () => {
  const cols = (await db.query("SELECT column_name FROM information_schema.columns WHERE table_name IN ('messages','whiteboard_sessions')")).rows.map((r) => r.column_name);
  assert.ok(!cols.includes('body') && !cols.includes('strokes'));
  assert.ok(cols.includes('body_ciphertext') && cols.includes('strokes_ciphertext'));
});

test('memberships: members cannot grant themselves access', async () => {
  await assert.rejects(as(B, W1, "INSERT INTO memberships (user_id, workspace_id, role) VALUES ($1,$2,'admin')", [B, W2]), /row-level security/);
  await assert.rejects(as(C, W2, "UPDATE memberships SET role='admin' WHERE user_id=$1 AND workspace_id=$2", [B, W1]).then((r) => { if (r.length === 0) throw new Error('row-level security: no rows'); }));
});

test('create_workspace makes the caller its admin', async () => {
  const [{ create_workspace: id }] = await as(B, null, "SELECT create_workspace('Mine','mine')");
  const rows = await as(B, id, 'SELECT role FROM memberships WHERE workspace_id = $1 AND user_id = $2', [id, B]);
  assert.equal(rows[0].role, 'admin');
  await assert.rejects(as(null, null, "SELECT create_workspace('n','nn')"), /authentication required/);
});

test('users only see people they share a workspace with', async () => {
  const ids = (await as(B, W1, 'SELECT id FROM users')).map((r) => r.id).sort();
  assert.deepEqual(ids, [A, B].sort());
});

test('notifications go only to members of the workspace and are private', async () => {
  const ins = "INSERT INTO notifications (workspace_id, user_id, type) VALUES ($1,$2,'t')";
  await assert.rejects(as(A, W1, ins, [W1, C]), /row-level security/);
  await as(A, W1, ins, [W1, B]);
  assert.equal((await as(A, W1, 'SELECT * FROM notifications')).length, 0);
  assert.equal((await as(B, W1, 'SELECT * FROM notifications')).length, 1);
});

test('audit_events is append-only and admin-readable', async () => {
  await as(B, W1, "INSERT INTO audit_events (workspace_id, actor_id, action) VALUES ($1,$2,'x')", [W1, B]);
  assert.equal((await as(B, W1, 'SELECT * FROM audit_events')).length, 0);
  assert.equal((await as(A, W1, 'SELECT * FROM audit_events')).length, 1);
  await assert.rejects(db.query('UPDATE audit_events SET action = $1', ['y']), /append-only/);
  await assert.rejects(db.query('DELETE FROM audit_events'), /append-only/);
});
