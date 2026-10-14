import 'package:flutter/material.dart';
import '../models/recommendation_model.dart';

class RecommendationReasonCard extends StatelessWidget {
  final RankedMenu result;
  const RecommendationReasonCard({super.key, required this.result});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(70),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이 메뉴를 추천한 이유',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...result.reasons.map(
          (reason) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• $reason'),
          ),
        ),
      ],
    ),
  );
}
