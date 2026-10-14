import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HomeRecommendationSteps extends StatelessWidget {
  const HomeRecommendationSteps({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '내 취향을 담아 골라요',
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 18),
      const Row(
        children: [
          Expanded(
            child: _Step(icon: Icons.sentiment_satisfied_alt, label: '기분·상황'),
          ),
          Icon(Icons.chevron_right, size: 18, color: Color(0xFF9D8D87)),
          Expanded(
            child: _Step(
              icon: Icons.account_balance_wallet_outlined,
              label: '맵기·예산',
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: Color(0xFF9D8D87)),
          Expanded(
            child: _Step(icon: Icons.rice_bowl_outlined, label: '메뉴 추천'),
          ),
        ],
      ),
    ],
  );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Step({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: AppTheme.primaryColor, size: 28),
      const SizedBox(height: 8),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7F6D66)),
      ),
    ],
  );
}
