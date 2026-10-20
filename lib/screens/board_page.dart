import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/board_page_result.dart';
import '../widgets/board/board_feed_tile.dart';
import '../models/post_model.dart';
import '../routes/app_routes.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/post_service.dart';
import '../widgets/board/board_paged_list.dart';

class BoardPage extends StatefulWidget {
  final Future<BoardPageResult<PostModel>> Function(
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  )?
  loadPage;
  final String? viewerUid;
  const BoardPage({super.key, this.loadPage, this.viewerUid});

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
    final currentUid = widget.loadPage == null
        ? FirebaseAuth.instance.currentUser?.uid
        : widget.viewerUid;

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
        backgroundColor: Colors.white,
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
          load:
              widget.loadPage ?? (cursor) => PostService.getPage(after: cursor),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 88),
          header: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '한 끼의 경험을 나눠요.',
              style: TextStyle(color: Color(0xFF676B73)),
            ),
          ),
          separator: const Divider(height: 1),
          itemBuilder: (context, post) => BoardFeedTile(
            post: post,
            isLiked: currentUid != null && post.likedBy.contains(currentUid),
            onTap: () => _open(AppRoutes.boardDetail, arguments: post),
          ),
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
            elevation: 0,
            highlightElevation: 0,
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
}
