import 'package:flutter/material.dart';
import '../models/recommendation_model.dart';

class RecommendationReasonCard extends StatelessWidget {
  final RankedMenu result;
  const RecommendationReasonCard({super.key, required this.result});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이 메뉴를 추천한 이유',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFD5D69),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                result.reasons
                        .where((reason) => !reason.contains('예상 가격'))
                        .firstOrNull ??
                    result.reasons.firstOrNull ??
                    '선택한 조건에 맞는 메뉴예요.',
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            if (result.reasons.length > 1)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: '추천 이유 더보기',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '추천 이유',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final reason in result.reasons)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text('• $reason'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
