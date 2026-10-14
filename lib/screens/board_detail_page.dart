import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import '../models/post_model.dart';
import '../services/comment_service.dart';
import '../services/post_service.dart';
import '../routes/app_routes.dart';
import '../widgets/board/board_style.dart';
import '../widgets/board/board_post_card.dart';
import '../widgets/board/board_paged_list.dart';
import '../widgets/board/board_comment_item.dart';
import '../widgets/board/board_comments_header.dart';
import '../widgets/board/board_comment_input.dart';

class BoardDetailPage extends StatefulWidget {
  const BoardDetailPage({super.key});

  @override
  State<BoardDetailPage> createState() => _BoardDetailPageState();
}

class _BoardDetailPageState extends State<BoardDetailPage> {
  late String _postId;
  bool _isInitialized = false;
  bool _isCommentSubmitting = false;
  int _commentsRefresh = 0;
  Stream<PostModel?>? _postStream;
  final TextEditingController _commentController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final post = ModalRoute.of(context)!.settings.arguments as PostModel;
      _postId = post.id;
      _postStream = PostService.getPostStream(_postId);
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('게시글 삭제'),
        content: const Text('정말로 이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PostService.deletePost(_postId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('게시글이 삭제되었습니다.')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      }
    }
  }

  Future<void> _handleToggleLike() async {
    try {
      await PostService.toggleLike(_postId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _handleCreateComment() async {
    final content = _commentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('댓글 내용을 입력해주세요.')));
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    setState(() => _isCommentSubmitting = true);

    try {
      await CommentService.createComment(postId: _postId, content: content);
      if (!mounted) return;
      setState(() => _commentsRefresh++);
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 작성 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCommentSubmitting = false);
      }
    }
  }

  Future<void> _handleUpdateComment(CommentModel comment) async {
    final editController = TextEditingController(text: comment.content);

    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('댓글 수정'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '댓글 내용을 입력하세요',
            filled: true,
            fillColor: BoardStyle.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: BoardStyle.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BoardStyle.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, editController.text.trim()),
            child: const Text('수정'),
          ),
        ],
      ),
    );

    editController.dispose();

    if (newContent == null) return;

    if (newContent.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글 내용을 입력해주세요.')));
      }
      return;
    }

    try {
      await CommentService.updateComment(
        postId: _postId,
        commentId: comment.id,
        content: newContent,
      );
      if (mounted) {
        setState(() => _commentsRefresh++);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글이 수정되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 수정 실패: $e')));
      }
    }
  }

  Future<void> _handleDeleteComment(CommentModel comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('댓글 삭제'),
        content: const Text('정말로 이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await CommentService.deleteComment(
        postId: _postId,
        commentId: comment.id,
      );
      if (mounted) {
        setState(() => _commentsRefresh++);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글이 삭제되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: BoardStyle.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: BoardStyle.text,
        centerTitle: true,
        title: const Text('댓글', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<PostModel?>(
        stream: _postStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: BoardStyle.primary),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text('게시글을 불러올 수 없습니다.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('삭제된 게시글입니다.'));
          }

          final post = snapshot.data!;
          final bool isLiked =
              currentUid != null && post.likedBy.contains(currentUid);

          return Column(
            children: [
              Expanded(
                child: BoardPagedList<CommentModel>(
                  refreshKey: _commentsRefresh,
                  load: (cursor) =>
                      CommentService.getPage(_postId, after: cursor),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  itemsDecoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(7),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  separator: const Divider(height: 1, color: BoardStyle.line),
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BoardPostCard(
                        post: post,
                        isLiked: isLiked,
                        isAuthor: post.authorUid == currentUid,
                        onEdit: () => Navigator.pushNamed(
                          context,
                          AppRoutes.postWrite,
                          arguments: post,
                        ),
                        onDelete: _handleDelete,
                        onLike: _handleToggleLike,
                      ),
                      const SizedBox(height: 16),
                      BoardCommentsHeader(commentCount: post.commentCount),
                      const SizedBox(height: 12),
                    ],
                  ),
                  empty: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 46,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.mode_comment_outlined,
                          color: Colors.grey,
                          size: 34,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '아직 댓글이 없습니다.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '첫 댓글을 작성해보세요!',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context, comment) => BoardCommentItem(
                    comment: comment,
                    currentUid: currentUid,
                    onEdit: _handleUpdateComment,
                    onDelete: _handleDeleteComment,
                  ),
                ),
              ),
              BoardCommentInput(
                nickname: FirebaseAuth.instance.currentUser?.displayName ?? '나',
                controller: _commentController,
                submitting: _isCommentSubmitting,
                onSubmit: _handleCreateComment,
              ),
            ],
          );
        },
      ),
    );
  }
}
