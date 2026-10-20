import 'package:flutter/material.dart';
import '../models/menu_model.dart';
import '../core/theme/app_theme.dart';
import 'recommendation/recommendation_controls.dart';

class MenuSummaryCard extends StatelessWidget {
  final MenuModel menu;
  const MenuSummaryCard({super.key, required this.menu});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          menu.imageAssetPath,
          height: 215,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 220,
            child: Icon(Icons.restaurant, size: 64),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                menu.category,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              menu.menuName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '예상 ${RecommendationControls.formatPrice(menu.budgetMin)}–${RecommendationControls.formatPrice(menu.budgetMax)}원',
              style: const TextStyle(fontSize: 16, color: AppTheme.mutedColor),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: const Icon(
                    Icons.local_fire_department_outlined,
                    size: 18,
                  ),
                  side: BorderSide.none,
                  backgroundColor: AppTheme.panelColor,
                  label: Text('맵기 ${menu.spicyLevel}'),
                ),
                Chip(
                  avatar: const Icon(Icons.rice_bowl_outlined, size: 18),
                  side: BorderSide.none,
                  backgroundColor: AppTheme.panelColor,
                  label: Text('포만감 ${menu.fullness}'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
