import 'package:flutter/material.dart';
import 'board_style.dart';
import '../../models/post_model.dart';
import 'board_avatar.dart';
import 'board_stat_chip.dart';

class BoardPostCard extends StatelessWidget {
  final PostModel post;
  final bool isLiked;
  final bool isAuthor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLike;
  const BoardPostCard({
    super.key,
    required this.post,
    required this.isLiked,
    required this.isAuthor,
    required this.onEdit,
    required this.onDelete,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BoardAvatar(
                nickname: post.authorNickname,
                radius: 20,
                fontSize: 15,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorNickname,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BoardStyle.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boardFormatDateTime(post.createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (isAuthor)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '게시글 수정',
                ),
              if (isAuthor)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  tooltip: '게시글 삭제',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 21,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: BoardStyle.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: BoardStyle.text,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(999),
                child: BoardStatChip(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: post.likeCount.toString(),
                  color: isLiked ? BoardStyle.primary : Colors.grey,
                  backgroundColor: isLiked
                      ? const Color(0xFFFFF0F1)
                      : BoardStyle.softPink,
                ),
              ),
              const SizedBox(width: 8),
              BoardStatChip(
                icon: Icons.mode_comment_outlined,
                label: post.commentCount.toString(),
                color: Colors.grey,
                backgroundColor: BoardStyle.background,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
