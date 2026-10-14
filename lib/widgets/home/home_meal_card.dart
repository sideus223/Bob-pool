import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/home_hero_image_service.dart';

class HomeMealCard extends StatelessWidget {
  final VoidCallback onRecommend;
  const HomeMealCard({super.key, required this.onRecommend});

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFFFE5DF),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.7,
              child: FutureBuilder<String>(
                future: HomeHeroImageService.instance.imageForSession,
                builder: (context, snapshot) => snapshot.hasData
                    ? Image.asset(
                        snapshot.data!,
                        key: const ValueKey('home-session-photo'),
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
                      )
                    : const _PhotoPlaceholder(),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(240),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(
                    '오늘의 한 끼',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRecommend,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text('나에게 맞는 메뉴 찾기', textAlign: TextAlign.center),
                  ),
                  Icon(Icons.chevron_right, size: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFFFE5DF),
    child: Center(
      child: Icon(
        Icons.rice_bowl_outlined,
        color: AppTheme.primaryColor,
        size: 64,
      ),
    ),
  );
}
