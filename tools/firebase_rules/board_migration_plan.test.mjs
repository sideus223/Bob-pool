import { test } from 'node:test';
import assert from 'node:assert/strict';
import { boardMigrationPlan } from './board_migration_plan.mjs';

const root = 'projects/demo-bobpool/databases/(default)/documents/';
const post = (id, fields = {}) => ({ name: root + 'posts/' + id, updateTime: '2026-10-12T00:00:00Z', fields });
const comment = (id, parent = 'p') => ({ name: root + `posts/${parent}/comments/${id}` });

test('backfill preserves content and reserves all historical orphan parents atomically', () => {
  const source = post('p', { content: { stringValue: 'preserve' } });
  const plan = boardMigrationPlan('demo-bobpool', [source], [comment('a'), comment('b'), comment('c', 'orphan')]);
  assert.deepEqual(plan.summary, { posts: 1, comments: 3, updatedPosts: 1, orphanMarkers: 1 });
  assert.equal(source.fields.content.stringValue, 'preserve');
  assert.deepEqual(plan.writes[0].updateMask.fieldPaths, ['deleted', 'commentCount']);
  assert.equal(plan.writes[0].update.fields.commentCount.integerValue, '2');
  assert.equal(plan.writes[0].currentDocument.updateTime, source.updateTime);
  assert.equal(plan.writes[1].currentDocument.exists, false);
  assert.equal(plan.writes[1].update.fields.deleted.booleanValue, true);
  assert.equal(plan.writes[1].update.fields.content.stringValue, '');
});

test('repeat migration is a no-op and never revives a tombstone', () => {
  const active = post('p', { deleted: { booleanValue: false }, commentCount: { integerValue: '1' } });
  const tombstone = post('gone', { deleted: { booleanValue: true }, commentCount: { integerValue: '0' } });
  const plan = boardMigrationPlan('demo-bobpool', [active, tombstone], [comment('a'), comment('b', 'gone')]);
  assert.equal(plan.writes.length, 0);
});

test('wrong project and unexpected nested collections fail closed', () => {
  assert.throws(() => boardMigrationPlan('other-project', [post('p')], []));
  assert.throws(() => boardMigrationPlan('demo-bobpool', [], [{ name: root + 'users/u/comments/c' }]));
});
