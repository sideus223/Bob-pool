import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/services/post_service.dart';
import 'package:bp2/services/comment_service.dart';
import 'package:bp2/services/board_write_limiter.dart';

Map<String, dynamic> post(String uid, {bool deleted = false}) => {
  'title': deleted ? '' : '글',
  'content': deleted ? '' : '본문',
  'authorUid': uid,
  'authorNickname': deleted ? '' : '작성자',
  'createdAt': Timestamp.fromMillisecondsSinceEpoch(100),
  'updatedAt': Timestamp.fromMillisecondsSinceEpoch(100),
  'likedBy': <String>[],
  'commentCount': 0,
  'deleted': deleted,
};

void main() {
  test(
    'post pages bound reads, exclude tombstones and use stable tie cursors',
    () async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < 45; i++) {
        await db
            .doc('posts/p${i.toString().padLeft(3, '0')}')
            .set(post('alice'));
      }
      await db.doc('posts/deleted').set(post('alice', deleted: true));
      final first = await PostService.getPage(firestore: db);
      final second = await PostService.getPage(
        firestore: db,
        after: first.cursor,
      );
      final third = await PostService.getPage(
        firestore: db,
        after: second.cursor,
      );
      expect(
        [first.items.length, second.items.length, third.items.length],
        [20, 20, 5],
      );
      expect(first.hasMore, isTrue);
      expect(third.hasMore, isFalse);
      expect(
        {
          ...first.items.map((p) => p.id),
          ...second.items.map((p) => p.id),
          ...third.items.map((p) => p.id),
        }.length,
        45,
      );
    },
  );

  test('my post pages remain author-scoped and server-sorted', () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 25; i++) {
      await db.doc('posts/a$i').set(post('alice'));
      await db.doc('posts/b$i').set(post('bob'));
    }
    final first = await PostService.getPage(
      firestore: db,
      mine: true,
      uid: 'alice',
    );
    final next = await PostService.getPage(
      firestore: db,
      mine: true,
      uid: 'alice',
      after: first.cursor,
    );
    expect(first.items.length, 20);
    expect(next.items.length, 5);
    expect(
      [...first.items, ...next.items].every((p) => p.authorUid == 'alice'),
      isTrue,
    );
  });

  test(
    'comment pages bound reads and retain all tied-time comments across cursors',
    () async {
      final db = FakeFirebaseFirestore();
      for (var i = 0; i < 65; i++) {
        await db.doc('posts/p/comments/c${i.toString().padLeft(3, '0')}').set({
          'content': '댓글',
          'authorUid': 'alice',
          'authorNickname': '작성자',
          'createdAt': Timestamp.fromMillisecondsSinceEpoch(100),
          'updatedAt': Timestamp.fromMillisecondsSinceEpoch(100),
        });
      }
      final first = await CommentService.getPage('p', firestore: db);
      final second = await CommentService.getPage(
        'p',
        firestore: db,
        after: first.cursor,
      );
      final third = await CommentService.getPage(
        'p',
        firestore: db,
        after: second.cursor,
      );
      expect(
        [first.items.length, second.items.length, third.items.length],
        [30, 30, 5],
      );
      expect(
        {
          ...first.items.map((c) => c.id),
          ...second.items.map((c) => c.id),
          ...third.items.map((c) => c.id),
        }.length,
        65,
      );
    },
  );

  test(
    'client creation atomically records exact target quota and parent count',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('posts/p').set(post('alice'));
      await BoardWriteLimiter.create(
        firestore: db,
        uid: 'alice',
        target: db.doc('posts/p/comments/new'),
        parentPostId: 'p',
        data: {
          'content': '댓글',
          'authorUid': 'alice',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      final usage = (await db.doc('users/alice/boardLimits/comments').get())
          .data()!;
      expect(usage['postId'], 'p');
      expect(usage['commentId'], 'new');
      expect(usage['count'], 1);
      final parent = (await db.doc('posts/p').get()).data()!;
      expect(parent['commentCount'], 1);
      expect((parent['commentChange'] as Map)['id'], 'new');
      expect((await db.doc('posts/p/comments/new').get()).exists, isTrue);
    },
  );

  test(
    'client rejects deleted-parent writes without consuming quota',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('posts/p').set(post('alice', deleted: true));
      await expectLater(
        BoardWriteLimiter.create(
          firestore: db,
          uid: 'alice',
          target: db.doc('posts/p/comments/new'),
          parentPostId: 'p',
          data: {},
        ),
        throwsStateError,
      );
      expect(
        (await db.doc('users/alice/boardLimits/comments').get()).exists,
        isFalse,
      );
      expect((await db.doc('posts/p/comments/new').get()).exists, isFalse);
    },
  );

  test(
    'client preserves a window and applies daily limit and cooldown',
    () async {
      final db = FakeFirebaseFirestore();
      final now = DateTime.utc(2026, 10, 12);
      await db.doc('users/alice/boardLimits/posts').set({
        'lastWrite': Timestamp.fromDate(
          now.subtract(const Duration(seconds: 10)),
        ),
        'windowStart': Timestamp.fromDate(
          now.subtract(const Duration(hours: 1)),
        ),
        'count': 2,
        'postId': 'old',
        'commentId': '',
      });
      await expectLater(
        BoardWriteLimiter.create(
          firestore: db,
          uid: 'alice',
          target: db.doc('posts/new'),
          data: post('alice'),
          clock: () => now,
        ),
        throwsStateError,
      );
      await db.doc('users/alice/boardLimits/posts').update({
        'count': 20,
        'lastWrite': Timestamp.fromDate(
          now.subtract(const Duration(minutes: 1)),
        ),
      });
      await expectLater(
        BoardWriteLimiter.create(
          firestore: db,
          uid: 'alice',
          target: db.doc('posts/new'),
          data: post('alice'),
          clock: () => now,
        ),
        throwsStateError,
      );
      expect((await db.doc('posts/new').get()).exists, isFalse);
      await db.doc('users/alice/boardLimits/posts').update({
        'windowStart': Timestamp.fromDate(
          now.subtract(const Duration(hours: 25)),
        ),
      });
      await BoardWriteLimiter.create(
        firestore: db,
        uid: 'alice',
        target: db.doc('posts/new'),
        data: post('alice'),
        clock: () => now,
      );
      expect(
        (await db.doc('users/alice/boardLimits/posts').get()).data()!['count'],
        1,
      );
    },
  );
}
