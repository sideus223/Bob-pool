import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../routes/app_routes.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/post_service.dart';
import '../widgets/board/board_paged_list.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  int _refresh = 0;

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    if (mounted) setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF9),
        appBar: AppBar(
          title: const Text(
            '오늘의 게시판',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF32201C),
        ),
        body: BoardPagedList<PostModel>(
          refreshKey: _refresh,
          load: (cursor) => PostService.getPage(after: cursor),
          itemBuilder: (context, post) =>
              _buildPostCard(context, post, currentUid),
          empty: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notes, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  '아직 작성된 게시글이 없습니다.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF32201C),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '첫 번째 글을 작성해보세요.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FloatingActionButton.extended(
            onPressed: () => _open(AppRoutes.postWrite),
            backgroundColor: const Color(0xFFFD5D69),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              '글쓰기',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 2),
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    PostModel post,
    String? currentUid,
  ) {
    String timeStr = '';
    if (post.createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(post.createdAt!);
      if (difference.inMinutes < 60) {
        timeStr = '${difference.inMinutes}분 전';
      } else if (difference.inHours < 24) {
        timeStr = '${difference.inHours}시간 전';
      } else {
        timeStr = '${post.createdAt!.month}/${post.createdAt!.day}';
      }
    }

    final bool isLiked =
        currentUid != null && post.likedBy.contains(currentUid);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withAlpha(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _open(AppRoutes.boardDetail, arguments: post),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFFFC6C9),
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: Color(0xFFFD5D69),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorNickname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF32201C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[800], height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildIconStat(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    post.likeCount.toString(),
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  _buildIconStat(
                    Icons.chat_bubble_outline,
                    post.commentCount.toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconStat(
    IconData icon,
    String count, {
    Color color = Colors.grey,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(count, style: TextStyle(color: color, fontSize: 14)),
      ],
    );
  }
}
