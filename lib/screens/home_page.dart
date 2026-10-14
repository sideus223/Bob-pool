import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/home/home_meal_card.dart';
import '../widgets/home/home_recommendation_steps.dart';
import '../widgets/home/home_shortcut_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final name = AuthService.currentUser?.name ?? '사용자';
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 24,
        backgroundColor: AppTheme.backgroundColor,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rice_bowl, color: AppTheme.primaryColor, size: 28),
            SizedBox(width: 8),
            Text(
              '밥풀',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton.filledTonal(
            tooltip: '설정',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8EEEA),
            ),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          children: [
            if (AppConfig.demoMode) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(Icons.phone_android, size: 18),
                  label: Text('로컬 데모 · 로그인 없이 체험'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '안녕하세요, $name님!',
              style: const TextStyle(
                color: Color(0xFF7F6D66),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '오늘은\n뭐 먹을까요?',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '기분과 취향에 맞는 한 끼를 찾아봐요.',
              style: TextStyle(color: Color(0xFF7F6D66), height: 1.5),
            ),
            const SizedBox(height: 20),
            HomeMealCard(
              onRecommend: () =>
                  Navigator.pushNamed(context, AppRoutes.randomMenu),
            ),
            const SizedBox(height: 24),
            const HomeRecommendationSteps(),
            const SizedBox(height: 24),
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
                    icon: Icons.forum_outlined,
                    title: '오늘의 게시판',
                    subtitle: AppConfig.demoMode
                        ? '연결 버전에서 이용 가능'
                        : '한 끼의 경험을 나눠요',
                    showDemoBadge: AppConfig.demoMode,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.board),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}
