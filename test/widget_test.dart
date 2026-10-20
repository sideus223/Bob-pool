import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/main.dart';
import 'package:bp2/routes/app_routes.dart';
import 'package:bp2/services/user_menu_preference_service.dart';
import 'package:bp2/widgets/menu_summary_card.dart';
import 'package:bp2/services/local_recommend_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserMenuPreferenceService.scopeProvider = () => 'demo';
  });
  testWidgets(
    'demo opens without Firebase and identifies disconnected features',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      expect(find.text('로컬 데모 · 로그인 없이 체험'), findsOneWidget);
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.pushNamed(context, AppRoutes.board);
      await tester.pumpAndSettle();
      expect(find.text('로컬 데모를 체험하고 있어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('recommend, favorite, select once, recipe and rerank', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => LocalRecommendService.getAllMenus());
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('나에게 맞는 메뉴 찾기'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('이 조건으로 추천받기'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('이 조건으로 추천받기'));
    await tester.pumpAndSettle();
    expect(find.text('나를 위한 추천'), findsOneWidget);
    expect(find.text('이 메뉴를 추천한 이유'), findsNothing);
    expect(find.byTooltip('추천 이유 더보기'), findsNothing);
    final first = tester
        .widget<MenuSummaryCard>(find.byType(MenuSummaryCard))
        .menu
        .menuId;
    expect(
      (await UserMenuPreferenceService.snapshot(
        '무난함',
      )).history[first]!.recommendationCount,
      1,
    );
    await tester.scrollUntilVisible(
      find.text('좋아요 · 찜'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('좋아요 · 찜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('좋아요 · 찜'));
    await tester.pumpAndSettle();
    expect(await UserMenuPreferenceService.getFavoriteMenuIds(), [first]);
    await tester.ensureVisible(find.text('오늘은 이거 먹을래요'));
    await tester.tap(find.text('오늘은 이거 먹을래요'));
    await tester.pumpAndSettle();
    expect(
      (await UserMenuPreferenceService.snapshot('무난함')).selections[first],
      1,
    );
    expect(find.text('선택 기록 완료'), findsOneWidget);
    final learning = (await UserMenuPreferenceService.snapshot('무난함')).learning;
    expect(
      learning.sampleCount,
      1,
    ); // Like + select on one exposure train once.
    expect(learning.ready, isFalse);
    await tester.ensureVisible(find.text('레시피 보기'));
    await tester.tap(find.text('레시피 보기'));
    await tester.pumpAndSettle();
    expect(find.text('재료 준비'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      (await UserMenuPreferenceService.snapshot(
        '무난함',
      )).history[first]!.recommendationCount,
      1,
    );
    await tester.ensureVisible(find.text('다른 메뉴 보기'));
    await tester.tap(find.text('다른 메뉴 보기'));
    await tester.pumpAndSettle();
    final next = tester
        .widget<MenuSummaryCard>(find.byType(MenuSummaryCard))
        .menu
        .menuId;
    expect(next, isNot(first));
    expect(
      (await UserMenuPreferenceService.snapshot(
        '무난함',
      )).history[next]!.recommendationCount,
      1,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('invalid recommendation route has a recoverable empty state', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    Navigator.pushNamed(
      tester.element(find.byType(Scaffold).first),
      AppRoutes.recommendResult,
    );
    await tester.pumpAndSettle();
    expect(find.text('추천 화면에서 메뉴를 먼저 선택해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
