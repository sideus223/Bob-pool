import 'package:flutter/material.dart';
import 'board_style.dart';
import '../../models/comment_model.dart';
import 'board_avatar.dart';

class BoardCommentItem extends StatelessWidget {
  final CommentModel comment;
  final String? currentUid;
  final ValueChanged<CommentModel> onEdit;
  final ValueChanged<CommentModel> onDelete;
  const BoardCommentItem({
    super.key,
    required this.comment,
    required this.currentUid,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCommentAuthor =
        currentUid != null && currentUid == comment.authorUid;
    final isEdited =
        comment.updatedAt != null &&
        comment.createdAt != null &&
        comment.updatedAt != comment.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoardAvatar(
            nickname: comment.authorNickname,
            radius: 20,
            fontSize: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            comment.authorNickname,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: BoardStyle.text,
                            ),
                          ),
                          Text(
                            boardFormatDateTime(comment.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (isEdited)
                            const Text(
                              '수정됨',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isCommentAuthor)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 84),
                        icon: const Icon(
                          Icons.more_horiz,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit(comment);
                          } else if (value == 'delete') {
                            onDelete(comment);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('수정')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              '삭제',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: BoardStyle.text,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isCommentAuthor ? '수정/삭제 가능' : '댓글',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
