import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../models/board_page_result.dart';
import 'board_write_limiter.dart';
import 'board_latency_probe.dart';

class PostService {
  static void _validateContent(String title, String content) {
    if (title.trim().isEmpty || content.trim().isEmpty) throw '제목과 내용을 입력해주세요.';
    if (title.trim().length > 100 || content.trim().length > 5000) {
      throw '제목은 100자, 내용은 5,000자 이내로 입력해주세요.';
    }
  }

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const pageSize = 20;

  static Future<BoardPageResult<PostModel>> getPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    bool mine = false,
    FirebaseFirestore? firestore,
    String? uid,
  }) async {
    final database = firestore ?? _firestore;
    Query<Map<String, dynamic>> query = database
        .collection('posts')
        .where('deleted', isEqualTo: false);
    if (mine) {
      final account = uid ?? _auth.currentUser?.uid;
      if (account == null) throw StateError('로그인이 필요합니다.');
      query = query.where('authorUid', isEqualTo: account);
    }
    query = query
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId);
    if (after != null) query = query.startAfterDocument(after);
    final probeId = BoardLatencyProbe.nextQueryId();
    final queryWatch = BoardLatencyProbe.enabled
        ? (Stopwatch()..start())
        : null;
    final snapshot = await query
        .limit(pageSize)
        .get(const GetOptions(source: Source.server));
    queryWatch?.stop();
    final decodeWatch = BoardLatencyProbe.enabled
        ? (Stopwatch()..start())
        : null;
    final page = BoardPageResult(
      snapshot.docs.map(PostModel.fromFirestore).toList(growable: false),
      snapshot.docs.isEmpty ? after : snapshot.docs.last,
      snapshot.docs.length == pageSize,
    );
    decodeWatch?.stop();
    if (BoardLatencyProbe.enabled) {
      BoardLatencyProbe.emit('query', {
        'sample': probeId,
        'query_us': queryWatch!.elapsedMicroseconds,
        'decode_us': decodeWatch!.elapsedMicroseconds,
        'documents': snapshot.docs.length,
        'from_cache': snapshot.metadata.isFromCache,
        'first_page': after == null,
        'mine': mine,
      });
    }
    return page;
  }

  /// 실시간 단일 게시글 스트림
  static Stream<PostModel?> getPostStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map(
          (doc) => doc.exists && doc.data()?['deleted'] != true
              ? PostModel.fromFirestore(doc)
              : null,
        );
  }

  /// 게시글 작성
  static Future<void> createPost({
    required String title,
    required String content,
    String? nickname,
  }) async {
    _validateContent(title, content);
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    // 닉네임 결정 로직: 1.전달받은 nickname 2.유저 displayName 3.익명
    final authorNickname = nickname ?? user.displayName ?? '익명';

    await BoardWriteLimiter.create(
      firestore: _firestore,
      uid: user.uid,
      target: _firestore.collection('posts').doc(),
      data: {
        'title': title.trim(),
        'content': content.trim(),
        'authorUid': user.uid,
        'authorNickname': authorNickname,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'likedBy': [], // 반드시 빈 배열로 저장
        'deleted': false,
        'commentCount': 0,
      },
    );
  }

  /// 게시글 수정 (작성자만 가능)
  static Future<void> updatePost({
    required String postId,
    required String title,
    required String content,
  }) async {
    _validateContent(title, content);
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    final postRef = _firestore.collection('posts').doc(postId);
    final doc = await postRef.get();
    if (!doc.exists) throw '게시글이 존재하지 않습니다.';

    if (doc.data()?['authorUid'] != user.uid) {
      throw '작성자만 수정할 수 있습니다.';
    }

    await postRef.update({
      'title': title.trim(),
      'content': content.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 좋아요 토글 (updatedAt은 절대 수정하지 않음)
  static Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    final postRef = _firestore.collection('posts').doc(postId);
    final doc = await postRef.get();
    if (!doc.exists) return;

    final List<String> likedBy = List<String>.from(
      doc.data()?['likedBy'] ?? [],
    );

    if (likedBy.contains(user.uid)) {
      // 좋아요 취소: 오직 likedBy 필드만 update
      await postRef.update({
        'likedBy': FieldValue.arrayRemove([user.uid]),
      });
    } else {
      // 좋아요 추가: 오직 likedBy 필드만 update, arrayUnion으로 중복 방지
      await postRef.update({
        'likedBy': FieldValue.arrayUnion([user.uid]),
      });
    }
  }

  /// 게시글 삭제
  static Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw '로그인이 필요합니다.';

    final postRef = _firestore.collection('posts').doc(postId);
    final doc = await postRef.get();

    if (!doc.exists) return;

    final authorUid = doc.data()?['authorUid'];
    if (authorUid != user.uid) {
      throw '본인의 게시글만 삭제할 수 있습니다.';
    }

    await postRef.update({
      'deleted': true,
      'title': '',
      'content': '',
      'authorNickname': '',
      'likedBy': [],
      'commentCount': 0,
      'commentChange': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
