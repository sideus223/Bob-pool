import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/post_model.dart';
import 'board_avatar.dart';
import 'board_style.dart';

class BoardFeedTile extends StatelessWidget {
  final PostModel post;
  final bool isLiked;
  final VoidCallback onTap;
  const BoardFeedTile({
    super.key,
    required this.post,
    required this.isLiked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BoardAvatar(nickname: post.authorNickname),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  post.authorNickname,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                boardFormatDateTime(post.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            post.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.mutedColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 17,
                color: isLiked ? AppTheme.primaryColor : AppTheme.mutedColor,
              ),
              const SizedBox(width: 5),
              Text(
                '${post.likeCount}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedColor,
                ),
              ),
              const SizedBox(width: 18),
              const Icon(
                Icons.chat_bubble_outline,
                size: 17,
                color: AppTheme.mutedColor,
              ),
              const SizedBox(width: 5),
              Text(
                '${post.commentCount}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
