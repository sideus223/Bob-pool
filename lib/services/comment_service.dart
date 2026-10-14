import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import '../models/board_page_result.dart';
import 'board_write_limiter.dart';

class CommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> _commentsRef(String postId) {
    return _firestore.collection('posts').doc(postId).collection('comments');
  }

  static const pageSize = 30;

  static Future<BoardPageResult<CommentModel>> getPage(
    String postId, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    FirebaseFirestore? firestore,
  }) async {
    Query<Map<String, dynamic>> query = (firestore ?? _firestore)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .orderBy(FieldPath.documentId);
    if (after != null) query = query.startAfterDocument(after);
    final snapshot = await query
        .limit(pageSize)
        .get(const GetOptions(source: Source.server));
    return BoardPageResult(
      snapshot.docs.map(CommentModel.fromFirestore).toList(growable: false),
      snapshot.docs.isEmpty ? after : snapshot.docs.last,
      snapshot.docs.length == pageSize,
    );
  }

  /// 댓글 작성
  static Future<void> createComment({
    required String postId,
    required String content,
    String? nickname,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) throw '댓글 내용을 입력해주세요.';
    if (trimmedContent.length > 2000) throw '댓글은 2,000자 이내로 입력해주세요.';

    final authorNickname = nickname ?? user.displayName ?? '익명';

    await BoardWriteLimiter.create(
      firestore: _firestore,
      uid: user.uid,
      target: _commentsRef(postId).doc(),
      parentPostId: postId,
      data: {
        'content': trimmedContent,
        'authorUid': user.uid,
        'authorNickname': authorNickname,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// 댓글 수정 (작성자만 가능, content와 updatedAt만 변경)
  static Future<void> updateComment({
    required String postId,
    required String commentId,
    required String content,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) throw '댓글 내용을 입력해주세요.';
    if (trimmedContent.length > 2000) throw '댓글은 2,000자 이내로 입력해주세요.';

    final commentRef = _commentsRef(postId).doc(commentId);
    final doc = await commentRef.get();
    if (!doc.exists) throw '댓글이 존재하지 않습니다.';

    final data = doc.data();
    if (data?['authorUid'] != user.uid) {
      throw '댓글 작성자만 수정할 수 있습니다.';
    }

    await commentRef.update({
      'content': trimmedContent,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 댓글 삭제 (작성자만 가능)
  static Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    final commentRef = _commentsRef(postId).doc(commentId);
    try {
      await _firestore.runTransaction((tx) async {
        final parent = await tx.get(_firestore.collection('posts').doc(postId));
        final comment = await tx.get(commentRef);
        if (!comment.exists) return;
        if (comment.data()?['authorUid'] != user.uid) {
          throw '댓글 작성자만 삭제할 수 있습니다.';
        }
        tx.delete(commentRef);
        if (parent.exists && parent.data()?['deleted'] != true) {
          tx.update(parent.reference, {
            'commentCount': (parent.data()?['commentCount'] as int? ?? 0) - 1,
            'commentChange': {
              'id': commentId,
              'action': 'delete',
              'at': FieldValue.serverTimestamp(),
            },
          });
        }
      });
    } on FirebaseException catch (error) {
      // Cleanup of a known orphan remains possible without reading its content.
      // The rules reject this standalone deletion for an active parent.
      if (error.code != 'permission-denied') rethrow;
      await commentRef.delete();
    }
  }
}
