import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HomeShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showDemoBadge;
  final VoidCallback onTap;
  const HomeShortcutCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDemoBadge = false,
  });

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: AppTheme.panelColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 28),
                if (showDemoBadge) ...[
                  const SizedBox(width: 6),
                  const Text(
                    '데모',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 11,
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFF8A7974),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8A7974),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
