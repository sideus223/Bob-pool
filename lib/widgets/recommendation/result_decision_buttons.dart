import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ResultDecisionButtons extends StatelessWidget {
  final bool busy, selected;
  final VoidCallback onSelect, onNext;
  const ResultDecisionButtons({
    super.key,
    required this.busy,
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppTheme.lineColor)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: busy || selected ? null : onSelect,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(selected ? '선택 기록 완료' : '오늘은 이거 먹을래요'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onNext,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.mutedColor,
                backgroundColor: AppTheme.panelColor,
                side: const BorderSide(color: AppTheme.lineColor),
                minimumSize: const Size.fromHeight(46),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('다른 메뉴 보기'),
            ),
          ],
        ),
      ),
    ),
  );
}
