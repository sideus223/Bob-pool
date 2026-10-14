import 'package:flutter/material.dart';
import 'board_style.dart';
import '../../models/comment_model.dart';
import 'board_comment_item.dart';
import 'board_comments_header.dart';

class BoardCommentsSection extends StatelessWidget {
  final Stream<List<CommentModel>> commentsStream;
  final String? currentUid;
  final ValueChanged<CommentModel> onEdit;
  final ValueChanged<CommentModel> onDelete;
  const BoardCommentsSection({
    super.key,
    required this.commentsStream,
    required this.currentUid,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommentModel>>(
      stream: commentsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: BoardStyle.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '댓글을 불러올 수 없습니다: ${snapshot.error}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final comments = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BoardCommentsHeader(commentCount: comments.length),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
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
              child: comments.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 46,
                        horizontal: 24,
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
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                      itemCount: comments.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: BoardStyle.line),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return BoardCommentItem(
                          comment: comment,
                          currentUid: currentUid,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
