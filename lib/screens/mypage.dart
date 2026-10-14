import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/auth_service.dart';
import '../routes/app_routes.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const CircleAvatar(
            radius: 40,
            child: Icon(Icons.person_outline, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            '${user?.name ?? '사용자'}님',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(user?.email ?? '', textAlign: TextAlign.center),
          const SizedBox(height: 28),
          _item(
            context,
            Icons.restaurant_menu,
            '기분별 음식 관리',
            '기분에 맞는 메뉴를 직접 추가하거나 제외해요',
            AppRoutes.moodFoodManage,
          ),
          _item(
            context,
            Icons.favorite_border,
            '찜한 메뉴',
            '좋아요한 메뉴와 레시피를 다시 확인해요',
            AppRoutes.favoriteMenu,
          ),
          _item(
            context,
            Icons.edit_note,
            '내 게시글',
            '내가 나눈 한 끼 이야기',
            AppRoutes.myPosts,
          ),
          _item(
            context,
            Icons.settings_outlined,
            '설정',
            '계정 및 데이터 저장 안내',
            AppRoutes.settings,
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.pushNamed(context, route),
  );
}
