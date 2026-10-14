import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/local_recommend_service.dart';
import 'package:bp2/services/user_menu_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserMenuPreferenceService.scopeProvider = () => 'demo';
    UserMenuPreferenceService.clock = () => DateTime.utc(2026, 10, 11, 12);
  });
  test(
    'ranking reacts to exposure and soft feedback without recording queries',
    () async {
      const request = RecommendationRequest(
        mood: '무난함',
        situation: '혼밥',
        budget: 25000,
      );
      final first = (await LocalRecommendService.rank(
        request,
      )).first.menu.menuId;
      expect(
        (await LocalRecommendService.rank(request)).first.menu.menuId,
        first,
      );
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).history,
        isEmpty,
      );
      await UserMenuPreferenceService.recordRecommendation(first);
      final next = (await LocalRecommendService.rank(
        request,
      )).first.menu.menuId;
      expect(next, isNot(first));
      await UserMenuPreferenceService.dislikeMenuForMood(
        mood: '무난함',
        menuId: next,
      );
      final afterDislike = await LocalRecommendService.rank(request);
      final disliked = afterDislike.singleWhere((r) => r.menu.menuId == next);
      expect(disliked.contributions['dislike'], -60);
      await UserMenuPreferenceService.clearMoodCustomizations('무난함');
      final restored = (await LocalRecommendService.rank(
        request,
      )).singleWhere((r) => r.menu.menuId == next);
      expect(restored.score, disliked.score + 60);
    },
  );
  test(
    'production pick uses weighted draw and retains every hard constraint',
    () async {
      const request = RecommendationRequest(
        mood: '무난함',
        situation: '혼밥',
        budget: 10000,
        spicy: '순함',
      );
      final menus = await LocalRecommendService.getAllMenus();
      final excluded = menus
          .firstWhere((m) => m.budgetMax <= 10000 && m.spicyLevel == '순함')
          .menuId;
      await UserMenuPreferenceService.removeMoodForMenu(
        mood: '무난함',
        menuId: excluded,
      );
      final candidates = await LocalRecommendService.rank(request);
      expect(candidates, isNotEmpty);
      final rng = Random(42);
      final picked = <String>{};
      for (int i = 0; i < 1000; i++) {
        final result = LocalRecommendService.pick(candidates, random: rng);
        expect(result.menu.budgetMax, lessThanOrEqualTo(10000));
        expect(result.menu.spicyLevel, '순함');
        expect(result.menu.menuId, isNot(excluded));
        picked.add(result.menu.menuId);
      }
      expect(picked.length, greaterThan(1));
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).history,
        isEmpty,
      );
    },
  );
}
