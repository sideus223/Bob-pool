// Pure planner: never exports credentials or rewrites users' content.
export function boardMigrationPlan(project, posts, comments) {
  const root = `projects/${project}/databases/(default)/documents/`;
  const parents = new Map(posts.map(post => [post.name, post]));
  const counts = new Map();
  for (const comment of comments) {
    const relative = comment.name.slice(root.length);
    const parts = relative.split('/');
    if (!comment.name.startsWith(root) || parts.length !== 4 || parts[0] !== 'posts' || parts[2] !== 'comments') {
      throw new Error('Unexpected comment path: no changes planned');
    }
    const name = root + parts.slice(0, 2).join('/');
    counts.set(name, (counts.get(name) ?? 0) + 1);
  }
  const writes = [];
  let updatedPosts = 0, orphanMarkers = 0;
  for (const post of posts) {
    if (!post.name.startsWith(root + 'posts/') || post.name.slice(root.length).split('/').length !== 2 || !post.updateTime) {
      throw new Error('Unexpected post metadata: no changes planned');
    }
    const deleted = post.fields?.deleted?.booleanValue === true;
    const commentCount = deleted ? 0 : counts.get(post.name) ?? 0;
    if (post.fields?.deleted?.booleanValue === deleted &&
        Number(post.fields?.commentCount?.integerValue) === commentCount) continue;
    writes.push({
      update: { name: post.name, fields: {
        deleted: { booleanValue: deleted }, commentCount: { integerValue: String(commentCount) },
      } },
      updateMask: { fieldPaths: ['deleted', 'commentCount'] },
      currentDocument: { updateTime: post.updateTime },
    });
    updatedPosts++;
  }
  for (const name of counts.keys()) {
    if (parents.has(name)) continue;
    // A historical missing parent is reserved, never recovered as a live post.
    writes.push({ update: { name, fields: {
      deleted: { booleanValue: true }, title: { stringValue: '' }, content: { stringValue: '' },
      authorUid: { stringValue: 'migration-reserved' }, authorNickname: { stringValue: '' },
      likedBy: { arrayValue: { values: [] } }, commentCount: { integerValue: '0' },
      createdAt: { timestampValue: '1970-01-01T00:00:00Z' },
      updatedAt: { timestampValue: '1970-01-01T00:00:00Z' },
    } }, currentDocument: { exists: false } });
    orphanMarkers++;
  }
  return { writes, summary: { posts: posts.length, comments: comments.length, updatedPosts, orphanMarkers } };
}
