import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/core/theme/app_theme.dart';
import 'package:bp2/widgets/recommendation/mood_mascot.dart';
import 'package:bp2/widgets/recommendation/recommendation_controls.dart';

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('moods share a row and spicy/budget stay expanded at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var mood = '무난함', situation = '혼밥', spicy = '상관없음';
      var budget = 25000.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (context, update) => RecommendationControls(
                  mood: mood,
                  situation: situation,
                  spicy: spicy,
                  budget: budget,
                  onMood: (value) => update(() => mood = value),
                  onSituation: (value) => update(() => situation = value),
                  onSpicy: (value) => update(() => spicy = value),
                  onBudget: (value) => update(() => budget = value),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('맵기는 어느 정도?'), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-slider')), findsOneWidget);
      final positions = [
        for (var i = 0; i < 5; i++)
          tester.getTopLeft(find.byType(MoodMascot).at(i)).dy,
      ];
      expect(positions.toSet(), hasLength(1));
      await tester.tap(find.text('매움'));
      await tester.pump();
      expect(spicy, '매움');
      expect(find.bySemanticsLabel('맵기 매움'), findsOneWidget);
      await tester.ensureVisible(find.byType(Slider));
      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      await tester.pump();
      expect(budget, 28000);
      expect(find.text('28,000원'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large Korean text wraps choices without losing controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RecommendationControls(
                mood: '무난함',
                situation: '혼밥',
                spicy: '상관없음',
                budget: 25000,
                onMood: (_) {},
                onSituation: (_) {},
                onSpicy: (_) {},
                onBudget: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byType(Slider));
    await tester.pump();
    expect(find.text('25,000원'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
