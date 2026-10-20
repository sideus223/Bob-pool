import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'mood_mascot.dart';

class RecommendationControls extends StatelessWidget {
  final String mood, situation, spicy;
  final double budget;
  final ValueChanged<String> onMood, onSituation, onSpicy;
  final ValueChanged<double> onBudget;
  const RecommendationControls({
    super.key,
    required this.mood,
    required this.situation,
    required this.spicy,
    required this.budget,
    required this.onMood,
    required this.onSituation,
    required this.onSpicy,
    required this.onBudget,
  });

  static const moods = ['기분 좋음', '무난함', '우울함', '스트레스', '피곤함'];
  static const situations = ['혼밥', '친구랑', '데이트', '든든하게', '가볍게', '빨리먹기'];
  static const icons = [
    Icons.person_outline,
    Icons.people_outline,
    Icons.favorite_border,
    Icons.rice_bowl_outlined,
    Icons.eco_outlined,
    Icons.schedule,
  ];
  static const spicyLevels = ['상관없음', '순함', '보통', '매움'];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(12) > 16;
      final moodColumns = constraints.maxWidth >= 300 && !largeText ? 5 : 3;
      final moodWidth =
          (constraints.maxWidth - (moodColumns - 1) * 6) / moodColumns;
      final situationColumns = largeText ? 2 : 3;
      final situationWidth =
          (constraints.maxWidth - (situationColumns - 1) * 8) /
          situationColumns;
      final spiceColumns = largeText ? 2 : 4;
      final spiceWidth =
          (constraints.maxWidth - (spiceColumns - 1) * 8) / spiceColumns;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '원하는 조건만 골라보세요.',
            style: TextStyle(fontSize: 14, color: AppTheme.mutedColor),
          ),
          const SizedBox(height: 4),
          const _Title('오늘 기분은 어때요?'),
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('mood-choices'),
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in moods)
                SizedBox(
                  width: moodWidth,
                  child: _Choice(
                    label: value,
                    selected: mood == value,
                    onTap: () => onMood(value),
                    verticalPadding: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 47,
                          child: MoodMascot(mood: value),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: mood == value
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: mood == value
                                ? AppTheme.primaryColor
                                : AppTheme.mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const _Title('오늘의 상황은?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < situations.length; i++)
                SizedBox(
                  width: situationWidth,
                  child: _Choice(
                    label: situations[i],
                    selected: situation == situations[i],
                    onTap: () => onSituation(situations[i]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[i],
                          size: 20,
                          color: situation == situations[i]
                              ? AppTheme.primaryColor
                              : AppTheme.textColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            situations[i],
                            style: TextStyle(
                              fontSize: 13,
                              color: situation == situations[i]
                                  ? AppTheme.primaryColor
                                  : AppTheme.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const _Title('맵기는 어느 정도?'),
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('spicy-choices'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < spicyLevels.length; i++)
                SizedBox(
                  width: spiceWidth,
                  child: _Choice(
                    label: '맵기 ${spicyLevels[i]}',
                    selected: spicy == spicyLevels[i],
                    onTap: () => onSpicy(spicyLevels[i]),
                    verticalPadding: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var j = 0; j < (i < 2 ? 1 : i); j++)
                              CustomPaint(
                                size: const Size(18, 22),
                                painter: _PepperPainter(
                                  spicy == spicyLevels[i]
                                      ? AppTheme.primaryColor
                                      : AppTheme.textColor,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          spicyLevels[i],
                          style: TextStyle(
                            fontSize: 12,
                            color: spicy == spicyLevels[i]
                                ? AppTheme.primaryColor
                                : AppTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Title('최대 예산'),
              Flexible(
                child: Text(
                  '${formatPrice(budget.toInt())}원',
                  key: const ValueKey('selected-budget'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbColor: Colors.white,
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.lineColor,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              key: const ValueKey('budget-slider'),
              value: budget,
              min: 5000,
              max: 50000,
              divisions: 45,
              label: '${formatPrice(budget.toInt())}원',
              semanticFormatterCallback: (value) =>
                  '최대 ${formatPrice(value.toInt())}원',
              onChanged: onBudget,
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '5,000원',
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedColor),
                ),
              ),
              Expanded(
                child: Text(
                  '50,000원',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '메뉴의 예상 가격 상한 기준이에요.',
            style: TextStyle(fontSize: 12, color: AppTheme.mutedColor),
          ),
        ],
      );
    },
  );

  static String formatPrice(int amount) => amount.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );
}

class _Choice extends StatelessWidget {
  final bool selected;
  final String label;
  final Widget child;
  final VoidCallback onTap;
  final double verticalPadding;
  const _Choice({
    required this.selected,
    required this.label,
    required this.child,
    required this.onTap,
    this.verticalPadding = 12,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    onTap: onTap,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? const Color(0xFFFFF1F4) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppTheme.primaryColor : AppTheme.lineColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: verticalPadding,
                ),
                child: Center(child: child),
              ),
            ),
            if (selected)
              const Positioned(
                top: 3,
                right: 3,
                child: Icon(
                  Icons.check_circle,
                  size: 13,
                  color: AppTheme.primaryColor,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PepperPainter extends CustomPainter {
  final Color color;
  _PepperPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 22);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(13, 6)
        ..cubicTo(19, 17, 9, 21, 2, 20)
        ..cubicTo(10, 16, 7, 10, 13, 6)
        ..close(),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 7)
        ..quadraticBezierTo(15, 2, 11, 2),
      pen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PepperPainter oldDelegate) => oldDelegate.color != color;
}
