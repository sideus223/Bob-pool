/** Owner-only migration. Dry-run by default; print counts, never content/tokens. */
import { createRequire } from 'node:module';
import { resolve, relative, isAbsolute } from 'node:path';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { boardMigrationPlan } from './board_migration_plan.mjs';

const args = process.argv.slice(2);
const project = args[args.indexOf('--project') + 1];
if (!args.includes('--project') || !/^[a-z][a-z0-9-]{4,62}$/.test(project ?? '')) {
  throw new Error('An explicit --project <Firebase project ID> is required');
}
const apply = args.includes('--apply');
if (apply && (!args.includes('--confirm-project') || args[args.indexOf('--confirm-project') + 1] !== project)) {
  throw new Error('--apply requires matching --confirm-project');
}
const workspace = fileURLToPath(new URL('../../', import.meta.url));
const backupRoot = resolve(workspace, 'tmp/board-migration');
const backupDirectory = resolve(backupRoot, new Date().toISOString().replaceAll(':', '-'));
const inside = relative(backupRoot, backupDirectory);
if (!inside || inside.startsWith('..') || isAbsolute(inside)) throw new Error('Invalid backup destination');

const require = createRequire(import.meta.url);
const auth = require('firebase-tools/lib/auth.js');
const account = auth.getProjectDefaultAccount(workspace);
if (!account?.tokens?.refresh_token) throw new Error('Sign in using firebase login; no credentials belong in source');
const tokens = await auth.getAccessToken(account.tokens.refresh_token, account.tokens.scopes);
const database = `projects/${project}/databases/(default)`;
const prefix = `https://firestore.googleapis.com/v1/${database}`;
async function request(path, body) {
  const response = await fetch(prefix + path, {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(30000),
    headers: { Authorization: `Bearer ${tokens.access_token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`Firestore HTTP ${response.status}; response contents omitted`);
  return response.json();
}
async function inventory(collectionId, transaction, descendants = false) {
  const result = [];
  let cursor;
  do {
    const structuredQuery = {
      from: [{ collectionId, allDescendants: descendants }], limit: 200,
      orderBy: [{ field: { fieldPath: '__name__' }, direction: 'ASCENDING' }],
      ...(cursor ? { startAt: { values: [{ referenceValue: cursor }], before: false } } : {}),
    };
    const page = await request('/documents:runQuery', { structuredQuery, transaction });
    const documents = page.flatMap(row => row.document ? [row.document] : []);
    result.push(...documents);
    cursor = documents.length === 200 ? documents.at(-1).name : undefined;
    if (result.length > 10000) throw new Error('Inventory exceeds the reviewed 10000-document limit');
  } while (cursor);
  return result;
}

const { transaction } = await request('/documents:beginTransaction', { options: apply ? { readWrite: {} } : { readOnly: {} } });
let finished = false;
try {
  const posts = await inventory('posts', transaction);
  const comments = await inventory('comments', transaction, true);
  const plan = boardMigrationPlan(project, posts, comments);
  if (plan.writes.length > 450) throw new Error('Too many migration writes for one reviewed atomic commit');
  if (apply && plan.writes.length) {
    await mkdir(backupDirectory, { recursive: true });
    // Contains user records, no auth tokens. tmp is excluded from Git.
    await writeFile(resolve(backupDirectory, 'before.json'), JSON.stringify({ project, posts, comments }, null, 2), { flag: 'wx', mode: 0o600 });
    await request('/documents:commit', { transaction, writes: plan.writes });
    finished = true;
  }
  console.log(JSON.stringify({ mode: apply ? 'applied' : 'dry-run', project, ...plan.summary,
    ...(apply && plan.writes.length ? { backup: backupDirectory } : {}) }));
} finally {
  if (!finished) await request('/documents:rollback', { transaction });
}
