import 'package:cloud_firestore/cloud_firestore.dart';

/// The rules independently verify this counter and its exact new document.
class BoardWriteLimiter {
  static Future<void> create({
    required FirebaseFirestore firestore,
    required String uid,
    required DocumentReference<Map<String, dynamic>> target,
    required Map<String, dynamic> data,
    String? parentPostId,
    DateTime Function()? clock,
  }) async {
    final kind = parentPostId == null ? 'posts' : 'comments';
    final usage = firestore.doc('users/$uid/boardLimits/$kind');
    try {
      await firestore.runTransaction(
        (tx) async {
          final limit = await tx.get(usage);
          final parent = parentPostId == null
              ? null
              : await tx.get(firestore.doc('posts/$parentPostId'));
          if (parent != null &&
              (!parent.exists || parent.data()?['deleted'] == true)) {
            throw StateError('삭제된 게시글에는 댓글을 작성할 수 없어요.');
          }
          final previous = limit.data();
          final lastWrite = previous?['lastWrite'] as Timestamp?;
          final start = previous?['windowStart'] as Timestamp?;
          final now = (clock?.call() ?? DateTime.now()).toUtc();
          final interval = kind == 'posts' ? 30 : 5;
          final expired =
              start == null ||
              now.difference(start.toDate()).inSeconds >= 86400;
          if (lastWrite != null &&
              now.difference(lastWrite.toDate()).inSeconds < interval) {
            throw StateError('$interval초 간격으로 작성할 수 있어요. 잠시 후 다시 시도해 주세요.');
          }
          final count = expired ? 1 : (previous?['count'] as int) + 1;
          if (count > (kind == 'posts' ? 20 : 100)) {
            throw StateError('24시간 작성 한도를 사용했어요. 잠시 후 다시 시도해 주세요.');
          }
          tx.set(usage, {
            'windowStart': expired ? FieldValue.serverTimestamp() : start,
            'lastWrite': FieldValue.serverTimestamp(),
            'count': count,
            'postId': parentPostId ?? target.id,
            'commentId': parentPostId == null ? '' : target.id,
          });
          tx.set(target, data);
          if (parent != null) {
            tx.update(parent.reference, {
              'commentCount': (parent.data()?['commentCount'] as int? ?? 0) + 1,
              'commentChange': {
                'id': target.id,
                'action': 'create',
                'at': FieldValue.serverTimestamp(),
              },
            });
          }
        },
        timeout: const Duration(seconds: 15),
        maxAttempts: 3,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError('작성 제한 또는 게시글 상태를 확인해 주세요. 잠시 후 다시 시도해 주세요.');
      }
      rethrow;
    }
  }
}
