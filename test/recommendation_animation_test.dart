import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/main.dart';
import 'package:bp2/routes/app_routes.dart';
import 'package:bp2/services/local_recommend_service.dart';
import 'package:bp2/services/user_menu_preference_service.dart';
import 'package:bp2/widgets/recommendation/bobpool_cooker.dart';
import 'package:bp2/widgets/recommendation/result_decision_buttons.dart';

void main() {
  testWidgets(
    'unchecked plays cooker once then enables the same result actions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      UserMenuPreferenceService.scopeProvider = () => 'animation-test';
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => LocalRecommendService.getAllMenus());
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      Navigator.pushNamed(
        tester.element(find.byType(Scaffold).first),
        AppRoutes.randomMenu,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('랜덤 추천'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('아무거나 추천받기'));
      await tester.tap(find.text('아무거나 추천받기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('랜덤 추천 결과'), findsNothing);
      expect(
        tester.widget<BobpoolCooker>(find.byType(BobpoolCooker)).animation,
        isNotNull,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('랜덤 추천 결과'), findsOneWidget);
      expect(
        tester
            .widget<ResultDecisionButtons>(find.byType(ResultDecisionButtons))
            .busy,
        isFalse,
      );
      final prefs = await UserMenuPreferenceService.snapshot('무난함');
      expect(
        prefs.history.values.fold<int>(
          0,
          (sum, item) => sum + item.recommendationCount,
        ),
        1,
      );
      final cooker = tester.widget<BobpoolCooker>(
        find.byType(BobpoolCooker, skipOffstage: false),
      );
      expect(cooker.animation, isNotNull);
      expect(cooker.animation!.value, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<BobpoolCooker>(find.byType(BobpoolCooker)).animation,
        isNull,
      );
      expect(find.text('아무거나 추천받기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
