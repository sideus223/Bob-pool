import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, getDoc, getDocs, collection, serverTimestamp, Timestamp, arrayUnion, arrayRemove, runTransaction, writeBatch, deleteField, query, where, limit, orderBy, documentId, startAfter } from 'firebase/firestore';

let environment;
before(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) throw new Error('Run through npm test: an emulator is required.');
  const [hostname, port] = host.split(':');
  environment = await initializeTestEnvironment({
    projectId: 'demo-bobpool',
    firestore: { host: hostname, port: Number(port), rules: await readFile(new URL('../../firebase/firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => { await environment?.cleanup(); });
beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async context => {
    const database = context.firestore();
    await setDoc(doc(database, 'posts/post'), { ...post('alice', Timestamp.fromMillis(1)), commentCount: 1 });
    await setDoc(doc(database, 'posts/post/comments/comment'), comment('alice', Timestamp.fromMillis(1)));
  });
});
function database(uid) { return uid ? environment.authenticatedContext(uid).firestore() : environment.unauthenticatedContext().firestore(); }
function post(uid, time = serverTimestamp()) {
  return { title: '한 끼', content: '오늘의 식사', authorUid: uid, authorNickname: '테스트', createdAt: time, updatedAt: time, likedBy: [], deleted: false, commentCount: 0 };
}
function comment(uid, time = serverTimestamp()) {
  return { content: '맛있겠어요', authorUid: uid, authorNickname: '테스트', createdAt: time, updatedAt: time };
}

function usage(postId, commentId = '', count = 1, windowStart = serverTimestamp()) {
  return { postId, commentId, count, windowStart, lastWrite: serverTimestamp() };
}
function createPost(uid, id = 'new', data = post(uid), quota = usage(id)) {
  const db = database(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}/boardLimits/posts`), quota);
  batch.set(doc(db, `posts/${id}`), data);
  return batch.commit();
}
async function createComment(uid, id = 'new', data = comment(uid), postId = 'post', quota = usage(postId, id)) {
  const db = database(uid);
  const parent = doc(db, `posts/${postId}`);
  const snapshot = await getDoc(parent);
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}/boardLimits/comments`), quota);
  batch.set(doc(db, `posts/${postId}/comments/${id}`), data);
  batch.update(parent, { commentCount: (snapshot.data()?.commentCount ?? 0) + 1,
    commentChange: { id, action: 'create', at: serverTimestamp() } });
  return batch.commit();
}
function softDelete(uid, id = 'post') {
  return updateDoc(doc(database(uid), `posts/${id}`), {
    deleted: true, title: '', content: '', authorNickname: '', likedBy: [], commentCount: 0,
    commentChange: deleteField(), updatedAt: serverTimestamp(),
  });
}
async function removeComment(uid, id = 'comment', postId = 'post') {
  const db = database(uid);
  const parent = doc(db, `posts/${postId}`);
  const snapshot = await getDoc(parent);
  const batch = writeBatch(db);
  batch.delete(doc(db, `posts/${postId}/comments/${id}`));
  batch.update(parent, { commentCount: snapshot.data().commentCount - 1,
    commentChange: { id, action: 'delete', at: serverTimestamp() } });
  return batch.commit();
}

function preferences(values = {}) {
  return { schemaVersion: 1, values, updatedAt: serverTimestamp() };
}

function learning(events = []) {
  return { version: 1, weights: Array(64).fill(0), sampleCount: 0,
    positives: 0, negatives: 0, distinctMenus: 0, events };
}

test('explicit feature model accepts the new dimension and preserves account isolation', async () => {
  const reference = doc(database('alice'), 'users/alice/preferences/current');
  const model = { ...learning(), version: 2, weights: Array(146).fill(0) };
  await assertSucceeds(setDoc(reference, preferences({ learning: model })));
  await assertSucceeds(getDoc(reference));
  await assertFails(getDoc(doc(database('bob'), 'users/alice/preferences/current')));
  await assertFails(setDoc(doc(database('bob'), 'users/alice/preferences/current'), preferences({ learning: model })));
  await assertFails(setDoc(reference, preferences({ learning: { ...model, weights: Array(64).fill(0) } })));
  await assertFails(setDoc(reference, preferences({ learning: { ...model, version: 1 } })));
});

test('learning model and logs remain private to the account with server time', async () => {
  const path = 'users/alice/preferences/current';
  const reference = doc(database('alice'), path);
  await assertSucceeds(setDoc(reference, preferences({ learning: learning([{ id: 'exposure', menuId: 'M001' }]) })));
  await assertSucceeds(getDoc(reference));
  await assertFails(getDoc(doc(database('bob'), path)));
  await assertFails(updateDoc(doc(database('bob'), path), { 'values.learning': learning(), updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(database(), path), preferences({ learning: learning() })));
  await assertFails(updateDoc(reference, { updatedAt: Timestamp.fromMillis(1) }));
});

test('sampling version and replay marker fit the existing private preference schema', async () => {
  const reference = doc(database('alice'), 'users/alice/preferences/current');
  await assertSucceeds(setDoc(reference, preferences({
    interaction_history: { M001: { recommendationCount: 1, selectionCount: 0,
      lastRecommendedAt: 1, lastSelectedAt: null, lastExposureId: 'exposure' } },
    learning: learning([{ id: 'exposure', menuId: 'M001', policy: 'rules-v2', policyVersion: 2 }]),
  })));
  const saved = (await getDoc(reference)).data().values;
  if (saved.learning.events[0].policyVersion !== 2 ||
      saved.interaction_history.M001.lastExposureId !== 'exposure') throw new Error('Lost sampling metadata');
  await assertFails(getDoc(doc(database('bob'), 'users/alice/preferences/current')));
});

test('learning schema rejects wrong versions, counts, dimensions and unbounded logs', async () => {
  const reference = doc(database('alice'), 'users/alice/preferences/current');
  for (const patch of [{ version: 99 }, { version: 2 }, { weights: [] }, { weights: 'bad' }, { sampleCount: -1 },
    { sampleCount: 65, positives: 65 }, { sampleCount: 1 }, { distinctMenus: 1 },
    { events: Array(65).fill({ id: 'x' }) }, { events: {} }, { extra: true }]) {
    await assertFails(setDoc(reference, preferences({ learning: { ...learning(), ...patch } })));
  }
});

test('legacy preferences without a learning state still work and reset stays private', async () => {
  const reference = doc(database('alice'), 'users/alice/preferences/current');
  await assertSucceeds(setDoc(reference, preferences({ favorites: ['M001'] })));
  await assertSucceeds(updateDoc(reference, { 'values.learning': learning(), updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(database('bob'), 'users/alice/preferences/current'),
    { 'values.learning': learning(), updatedAt: serverTimestamp() }));
});

test('two clients atomically retain both distinct learning events', async () => {
  const path = 'users/alice/preferences/current';
  await setDoc(doc(database('alice'), path), preferences({ learning: learning() }));
  const clients = [database('alice'), database('alice')];
  await Promise.all(clients.map((client, i) => runTransaction(client, async transaction => {
    const reference = doc(client, path);
    const snapshot = await transaction.get(reference);
    const events = snapshot.data().values.learning.events;
    transaction.set(reference, preferences({ learning: learning([...events, { id: String(i) }]) }));
  })));
  const result = (await getDoc(doc(database('alice'), path))).data().values.learning.events;
  if (result.length !== 2 || new Set(result.map(e => e.id)).size !== 2) throw new Error('Lost learning event');
});

test('preferences belong exclusively to the path UID', async () => {
  const path = 'users/alice/preferences/current';
  await assertSucceeds(setDoc(doc(database('alice'), path), preferences({ favorites: ['M001'] })));
  await assertSucceeds(getDoc(doc(database('alice'), path)));
  await assertFails(getDoc(doc(database('bob'), path)));
  await assertFails(getDoc(doc(database(), path)));
  await assertFails(setDoc(doc(database('bob'), path), preferences()));
  await assertFails(setDoc(doc(database(), path), preferences()));
  await assertFails(deleteDoc(doc(database('alice'), path)));
});

test('preference schema, server time, field types and list limits are enforced', async () => {
  const reference = doc(database('alice'), 'users/alice/preferences/current');
  for (const patch of [{ schemaVersion: 2 }, { updatedAt: Timestamp.fromMillis(1) }, { extra: true }, { values: [] },
    { values: { favorites: 'bad' } }, { values: { favorites: ['A', 'A'] } },
    { values: { favorites: Array.from({ length: 1001 }, (_, i) => String(i)) } },
    { values: { interaction_history: 'bad' } }, { values: { selections: [] } },
    { values: { 'disliked_무난함': 'bad' } }, { values: { arbitrary: true } }]) {
    await assertFails(setDoc(reference, { ...preferences(), ...patch }));
  }
});

test('only current document is accessible and collection-wide user queries fail', async () => {
  await assertFails(setDoc(doc(database('alice'), 'users/alice/preferences/other'), preferences()));
  await assertFails(getDoc(doc(database('alice'), 'users/alice/preferences/other')));
  await assertFails(getDocs(collection(database('alice'), 'users')));
  await assertFails(getDoc(doc(database('alice'), 'users/bob/preferences/current')));
});

test('reset writes an empty server document and cannot expose another account', async () => {
  const reference = doc(database('alice'), 'users/alice/preferences/current');
  await assertSucceeds(setDoc(reference, preferences({ favorites: ['M001'], 'disliked_무난함': ['M002'], interaction_history: { M001: { selectionCount: 1 } } })));
  await assertSucceeds(setDoc(reference, preferences()));
  await assertFails(updateDoc(doc(database('bob'), 'users/alice/preferences/current'), { values: {}, updatedAt: serverTimestamp() }));
  const snapshot = await assertSucceeds(getDoc(reference));
  if (Object.keys(snapshot.data().values).length !== 0) throw new Error('Reset failed');
});

test('transactions across two clients preserve concurrent choice counts', async () => {
  const path = 'users/alice/preferences/current';
  await assertSucceeds(setDoc(doc(database('alice'), path), preferences({ interaction_history: { M001: { selectionCount: 0 } } })));
  const clients = [database('alice'), database('alice')];
  await Promise.all(clients.map(client => runTransaction(client, async transaction => {
    const reference = doc(client, path);
    const snapshot = await transaction.get(reference);
    const count = snapshot.data().values.interaction_history.M001.selectionCount;
    transaction.set(reference, preferences({ interaction_history: { M001: { selectionCount: count + 1 } } }));
  })));
  const count = (await getDoc(doc(database('alice'), path))).data().values.interaction_history.M001.selectionCount;
  if (count !== 2) throw new Error('Concurrent choice lost');
});

test('authenticated users can query posts and comments; visitors cannot', async () => {
  await assertSucceeds(getDocs(query(collection(database('bob'), 'posts'), where('deleted', '==', false), limit(20))));
  await assertSucceeds(getDocs(query(collection(database('bob'), 'posts/post/comments'), limit(30))));
  await assertFails(getDoc(doc(database(), 'posts/post')));
  await assertFails(getDocs(collection(database(), 'posts/post/comments')));
});
test('a user can create a post with their UID and server timestamps', async () => {
  await assertSucceeds(createPost('alice', 'new', { ...post('alice'), content: '첫 줄\n둘째 줄' }));
});
test('unauthenticated and forged-author post creation is rejected', async () => {
  await assertFails(setDoc(doc(database(), 'posts/new'), post('alice')));
  await assertFails(createPost('bob', 'new', post('alice')));
});
test('post fields, text limits and creation metadata are enforced', async () => {
  const databaseAlice = database('alice');
  for (const [field, value] of [['title', ' '], ['content', '\n\t '], ['title', 'x'.repeat(101)], ['content', 'x'.repeat(5001)], ['authorNickname', 'x'.repeat(51)], ['likedBy', ['bob']], ['createdAt', Timestamp.fromMillis(1)], ['extra', true]]) {
    await assertFails(createPost('alice', 'new', { ...post('alice'), [field]: value }));
  }
});
test('the post author can edit content and delete their own post', async () => {
  const reference = doc(database('alice'), 'posts/post');
  await assertSucceeds(updateDoc(reference, { title: '수정', content: '수정 내용', updatedAt: serverTimestamp() }));
  await assertSucceeds(softDelete('alice'));
});
test('another account cannot edit or delete a post', async () => {
  const reference = doc(database('bob'), 'posts/post');
  await assertFails(updateDoc(reference, { content: '변조', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(reference));
});
test('even an author cannot rewrite ownership, creation time or extra fields', async () => {
  const reference = doc(database('alice'), 'posts/post');
  for (const patch of [{ authorUid: 'bob' }, { authorNickname: '위조' }, { createdAt: serverTimestamp() }, { extra: true }]) {
    await assertFails(updateDoc(reference, { ...patch, updatedAt: serverTimestamp() }));
  }
});
test('users may only add/remove their own like while retaining other likes', async () => {
  const alice = doc(database('alice'), 'posts/post');
  const bob = doc(database('bob'), 'posts/post');
  await assertSucceeds(updateDoc(alice, { likedBy: arrayUnion('alice') }));
  await assertSucceeds(updateDoc(bob, { likedBy: arrayUnion('bob') }));
  await assertSucceeds(updateDoc(bob, { likedBy: arrayRemove('bob') }));
  await assertFails(updateDoc(bob, { likedBy: [] }));
  await assertFails(updateDoc(bob, { likedBy: arrayUnion('charlie') }));
});
test('like updates cannot hide content edits or duplicate likes', async () => {
  const reference = doc(database('bob'), 'posts/post');
  await assertFails(updateDoc(reference, { likedBy: ['bob'], content: '변조' }));
  await assertFails(updateDoc(reference, { likedBy: ['bob', 'bob'] }));
  await assertFails(updateDoc(doc(database(), 'posts/post'), { likedBy: ['bob'] }));
});
test('a signed-in user may comment on an existing post with their own UID', async () => {
  await assertSucceeds(createComment('bob'));
});
test('unauthenticated, forged or oversized comments are rejected', async () => {
  await assertFails(setDoc(doc(database(), 'posts/post/comments/new'), comment('bob')));
  await assertFails(createComment('bob', 'new', comment('alice')));
  await assertFails(createComment('bob', 'new', { ...comment('bob'), content: 'x'.repeat(2001) }));
  await assertFails(createComment('bob', 'new', { ...comment('bob'), extra: true }));
});
test('only the comment author may edit or delete a comment', async () => {
  const alice = doc(database('alice'), 'posts/post/comments/comment');
  const bob = doc(database('bob'), 'posts/post/comments/comment');
  await assertFails(updateDoc(bob, { content: '변조', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(bob));
  await assertSucceeds(updateDoc(alice, { content: '수정', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(alice, { authorUid: 'bob', updatedAt: serverTimestamp() }));
  await assertSucceeds(removeComment('alice'));
});
test('a post author cannot edit or delete another user comment', async () => {
  await assertSucceeds(createComment('bob', 'bob'));
  const reference = doc(database('alice'), 'posts/post/comments/bob');
  await assertFails(updateDoc(reference, { content: '변조', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(reference));
});
test('deleted parents reject comment reads/new writes but permit author cleanup', async () => {
  await assertSucceeds(softDelete('alice'));
  await assertFails(getDoc(doc(database('alice'), 'posts/post/comments/comment')));
  await assertFails(setDoc(doc(database('alice'), 'posts/post/comments/new'), comment('alice')));
  await assertFails(updateDoc(doc(database('alice'), 'posts/post/comments/comment'), { content: '수정', updatedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(doc(database('alice'), 'posts/post/comments/comment')));
});
test('unknown collections are closed by default', async () => {
  await assertFails(setDoc(doc(database('alice'), 'admin/alice'), { admin: true }));
  await assertFails(getDoc(doc(database('alice'), 'admin/alice')));
});

test('unbounded and oversized board queries fail even through direct SDK', async () => {
  const db = database('bob');
  const posts = collection(db, 'posts');
  const comments = collection(db, 'posts/post/comments');
  await assertFails(getDocs(posts));
  await assertFails(getDocs(query(posts, where('deleted', '==', false), limit(21))));
  await assertFails(getDocs(query(posts, limit(20))));
  await assertFails(getDocs(comments));
  await assertFails(getDocs(query(comments, limit(31))));
});

test('post and comment pages preserve tied timestamps without omissions', async () => {
  await environment.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    const batch = writeBatch(db);
    for (let i = 0; i < 45; i++) batch.set(doc(db, `posts/p${String(i).padStart(3, '0')}`), post('alice', Timestamp.fromMillis(200)));
    for (let i = 0; i < 65; i++) batch.set(doc(db, `posts/post/comments/c${String(i).padStart(3, '0')}`), comment('alice', Timestamp.fromMillis(200)));
    await batch.commit();
  });
  const db = database('bob');
  const posts = query(collection(db, 'posts'), where('deleted', '==', false), orderBy('createdAt', 'desc'), orderBy(documentId()), limit(20));
  const first = await assertSucceeds(getDocs(posts));
  const next = await assertSucceeds(getDocs(query(posts, startAfter(first.docs.at(-1)))));
  if (first.size !== 20 || next.size !== 20 || new Set([...first.docs, ...next.docs].map(d => d.id)).size !== 40) throw Error('Post cursor overlap');
  const comments = query(collection(db, 'posts/post/comments'), orderBy('createdAt'), orderBy(documentId()), limit(30));
  const page = await assertSucceeds(getDocs(comments));
  const page2 = await assertSucceeds(getDocs(query(comments, startAfter(page.docs.at(-1)))));
  if (page.size !== 30 || page2.size !== 30 || new Set([...page.docs, ...page2.docs].map(d => d.id)).size !== 60) throw Error('Comment cursor overlap');
});

test('deleted ID cannot be recreated by its author or another account', async () => {
  await assertSucceeds(softDelete('alice'));
  await assertFails(createPost('bob', 'post', post('bob'), usage('post')));
  await assertFails(createPost('alice', 'post', post('alice'), usage('post')));
  await assertFails(deleteDoc(doc(database('alice'), 'posts/post')));
  await assertFails(updateDoc(doc(database('alice'), 'posts/post'), { deleted: false, title: '복원', content: '복원', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(database('bob'), 'posts/post'), { likedBy: ['bob'] }));
  const marker = (await assertSucceeds(getDoc(doc(database('bob'), 'posts/post')))).data();
  if (!marker.deleted || marker.title || marker.content || marker.authorNickname || marker.commentCount || marker.likedBy.length) throw Error('Tombstone leaked content');
  await assertFails(getDocs(query(collection(database('bob'), 'posts/post/comments'), limit(30))));
  const visible = await assertSucceeds(getDocs(query(collection(database('bob'), 'posts'), where('deleted', '==', false), limit(20))));
  if (visible.size) throw Error('Deleted post visible');
});

test('deletion must redact all content and cannot bundle a new comment', async () => {
  await assertFails(updateDoc(doc(database('alice'), 'posts/post'), { deleted: true, updatedAt: serverTimestamp() }));
  const db = database('alice');
  const batch = writeBatch(db);
  batch.update(doc(db, 'posts/post'), { deleted: true, title: '', content: '', authorNickname: '', likedBy: [], commentCount: 0, updatedAt: serverTimestamp() });
  batch.set(doc(db, 'posts/post/comments/new'), comment('alice'));
  batch.set(doc(db, 'users/alice/boardLimits/comments'), usage('post', 'new'));
  await assertFails(batch.commit());
});

test('legacy posts still support editing likes and permanent deletion', async () => {
  await environment.withSecurityRulesDisabled(async context => {
    const legacy = post('alice', Timestamp.fromMillis(1));
    delete legacy.deleted; delete legacy.commentCount;
    await setDoc(doc(context.firestore(), 'posts/legacy'), legacy);
  });
  await assertSucceeds(updateDoc(doc(database('alice'), 'posts/legacy'), { content: '수정', updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(database('bob'), 'posts/legacy'), { likedBy: ['bob'] }));
  await assertSucceeds(softDelete('alice', 'legacy'));
  await assertFails(createPost('bob', 'legacy', post('bob'), usage('legacy')));
});

test('creation cannot omit consume falsify or independently reset quota', async () => {
  const db = database('alice');
  await assertFails(setDoc(doc(db, 'posts/new'), post('alice')));
  await assertFails(setDoc(doc(db, 'users/alice/boardLimits/posts'), usage('new')));
  await assertFails(createPost('alice', 'new', post('alice'), usage('another')));
  await assertFails(createPost('alice', 'new', post('alice'), { ...usage('new'), count: 0 }));
  await assertFails(createPost('alice', 'new', post('alice'), { ...usage('new'), lastWrite: Timestamp.fromMillis(1) }));
  await assertSucceeds(createPost('alice'));
  await assertFails(deleteDoc(doc(db, 'users/alice/boardLimits/posts')));
  await assertFails(updateDoc(doc(db, 'users/alice/boardLimits/posts'), { count: 0 }));
  await assertFails(getDoc(doc(database('bob'), 'users/alice/boardLimits/posts')));
  await assertFails(setDoc(doc(database('bob'), 'users/alice/boardLimits/posts'), usage('x')));
});

test('quota cannot authorize two targets in a batch or replay a prior claim', async () => {
  const db = database('alice');
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts/new'), post('alice'));
  batch.set(doc(db, 'posts/other'), post('alice'));
  batch.set(doc(db, 'users/alice/boardLimits/posts'), usage('new'));
  await assertFails(batch.commit());
  await assertSucceeds(createPost('alice'));
  await assertFails(setDoc(doc(db, 'posts/another'), post('alice')));
});

async function seedLimit(uid, kind, { count = 1, age = 60, windowAge = 300 } = {}) {
  const start = Timestamp.fromMillis(Date.now() - windowAge * 1000);
  await environment.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), `users/${uid}/boardLimits/${kind}`), {
      ...usage('previous', kind === 'comments' ? 'previous' : '', count, start),
      lastWrite: Timestamp.fromMillis(Date.now() - age * 1000),
    });
  });
  return start;
}

test('post and comment intervals and daily ceilings are enforced by server time', async () => {
  let start = await seedLimit('alice', 'posts', { age: 0 });
  await assertFails(createPost('alice', 'new', post('alice'), usage('new', '', 2, start)));
  start = await seedLimit('alice', 'posts', { count: 20 });
  await assertFails(createPost('alice', 'new', post('alice'), usage('new', '', 21, start)));
  await assertFails(createPost('alice', 'new', post('alice'), usage('new')));
  start = await seedLimit('bob', 'comments', { age: 0 });
  await assertFails(createComment('bob', 'new', comment('bob'), 'post', usage('post', 'new', 2, start)));
  start = await seedLimit('bob', 'comments', { count: 100 });
  await assertFails(createComment('bob', 'new', comment('bob'), 'post', usage('post', 'new', 101, start)));
});

test('expired windows reset with server time while interval survives window reset', async () => {
  await seedLimit('alice', 'posts', { count: 20, windowAge: 90000, age: 0 });
  await assertFails(createPost('alice'));
  await seedLimit('alice', 'posts', { count: 20, windowAge: 90000 });
  await assertSucceeds(createPost('alice'));
  const start = await seedLimit('bob', 'comments', { count: 99 });
  await assertSucceeds(createComment('bob', 'new', comment('bob'), 'post', usage('post', 'new', 100, start)));
});

test('concurrent account creates cannot spend the same remaining quota twice', async () => {
  const start = await seedLimit('alice', 'posts', { count: 19 });
  const results = await Promise.allSettled([
    createPost('alice', 'one', post('alice'), usage('one', '', 20, start)),
    createPost('alice', 'two', post('alice'), usage('two', '', 20, start)),
  ]);
  if (results.filter(r => r.status === 'fulfilled').length !== 1) throw Error('Quota race');
});

test('comment count changes are coupled to one exact create or author delete', async () => {
  const db = database('bob');
  await assertFails(updateDoc(doc(db, 'posts/post'), { commentCount: 100 }));
  await assertFails(setDoc(doc(db, 'posts/post/comments/new'), comment('bob')));
  await assertSucceeds(createComment('bob'));
  let parent = await getDoc(doc(db, 'posts/post'));
  if (parent.data().commentCount !== 2) throw Error('Count did not increase');
  await assertFails(deleteDoc(doc(db, 'posts/post/comments/new')));
  await assertSucceeds(removeComment('bob', 'new'));
  parent = await getDoc(doc(db, 'posts/post'));
  if (parent.data().commentCount !== 1) throw Error('Count did not decrease');
  await assertFails(updateDoc(doc(db, 'posts/post'), { commentCount: 2,
    commentChange: { id: 'comment', action: 'create', at: serverTimestamp() } }));
});

test('a single comment counter delta cannot cover multiple comment creates', async () => {
  const db = database('bob');
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts/post/comments/one'), comment('bob'));
  batch.set(doc(db, 'posts/post/comments/two'), comment('bob'));
  batch.set(doc(db, 'users/bob/boardLimits/comments'), usage('post', 'one'));
  batch.update(doc(db, 'posts/post'), { commentCount: 2,
    commentChange: { id: 'one', action: 'create', at: serverTimestamp() } });
  await assertFails(batch.commit());
});
