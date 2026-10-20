import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/auth_service.dart';
import '../routes/app_routes.dart';
import '../widgets/bobpool_avatar.dart';
import '../widgets/home/home_shortcut_card.dart';
import '../core/theme/app_theme.dart';

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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.panelColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const BobpoolAvatar(radius: 38),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user?.name ?? '사용자'}님',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          user!.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.mutedColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HomeShortcutCard(
                  icon: Icons.favorite_border,
                  title: '찜한 메뉴',
                  subtitle: '다시 먹고 싶은 한 끼',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.favoriteMenu),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HomeShortcutCard(
                  icon: Icons.edit_note,
                  title: '내 게시글',
                  subtitle: '내가 나눈 한 끼 이야기',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.myPosts),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            '나의 밥풀',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _item(
            context,
            Icons.restaurant_menu,
            '기분별 음식 관리',
            '기분에 맞는 메뉴를 직접 추가하거나 제외해요',
            AppRoutes.moodFoodManage,
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
