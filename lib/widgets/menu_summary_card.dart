import 'package:flutter/material.dart';
import '../models/menu_model.dart';

class MenuSummaryCard extends StatelessWidget {
  final MenuModel menu;
  const MenuSummaryCard({super.key, required this.menu});
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          menu.imageAssetPath,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 220,
            child: Icon(Icons.restaurant, size: 64),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                menu.category,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                menu.menuName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(menu.recommendText),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(label: Text('₩${menu.budgetMin} ~ ₩${menu.budgetMax}')),
                  Chip(label: Text('맵기 ${menu.spicyLevel}')),
                  Chip(label: Text('포만감 ${menu.fullness}')),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
