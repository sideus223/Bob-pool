import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/services/user_menu_preference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'liked_menus_': ['legacy'],
    });
    UserMenuPreferenceService.scopeProvider = () => 'alice';
    UserMenuPreferenceService.clock = () => DateTime.utc(2026, 10, 11, 12);
  });
  tearDown(() {
    UserMenuPreferenceService.clock = () => DateTime.now().toUtc();
  });
  test(
    'accounts and demo are isolated; legacy data remains untouched',
    () async {
      await UserMenuPreferenceService.addFavoriteMenu('M001');
      UserMenuPreferenceService.scopeProvider = () => 'bob';
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), isEmpty);
      UserMenuPreferenceService.scopeProvider = () => 'demo';
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), isEmpty);
      UserMenuPreferenceService.scopeProvider = () => 'alice';
      expect(await UserMenuPreferenceService.getFavoriteMenuIds(), ['M001']);
      expect(
        (await SharedPreferences.getInstance()).getStringList('liked_menus_'),
        ['legacy'],
      );
    },
  );
  test(
    'simultaneous feedback writes retain every selection and favorite',
    () async {
      await Future.wait(
        List.generate(
          10,
          (i) => UserMenuPreferenceService.addFavoriteMenu('M$i'),
        ),
      );
      expect(
        await UserMenuPreferenceService.getFavoriteMenuIds(),
        hasLength(10),
      );
      await Future.wait(
        List.generate(
          10,
          (_) => UserMenuPreferenceService.recordSelection('M001'),
        ),
      );
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).selections['M001'],
        10,
      );
    },
  );
  test('pending writes keep the initiating account after a switch', () async {
    final pending = UserMenuPreferenceService.addFavoriteMenu('M001');
    UserMenuPreferenceService.scopeProvider = () => 'bob';
    await pending;
    expect(await UserMenuPreferenceService.getFavoriteMenuIds(), isEmpty);
    UserMenuPreferenceService.scopeProvider = () => 'alice';
    expect(await UserMenuPreferenceService.getFavoriteMenuIds(), ['M001']);
  });
  test(
    'mood toggles are exclusive and reset clears negative mood feedback',
    () async {
      await UserMenuPreferenceService.addMoodForMenu(
        menuId: 'M001',
        mood: '무난함',
      );
      await UserMenuPreferenceService.removeMoodForMenu(
        menuId: 'M001',
        mood: '무난함',
      );
      await UserMenuPreferenceService.dislikeMenuForMood(
        menuId: 'M001',
        mood: '무난함',
      );
      final before = await UserMenuPreferenceService.snapshot('무난함');
      expect(before.added, isEmpty);
      expect(before.removed, {'M001'});
      await UserMenuPreferenceService.clearMoodCustomizations('무난함');
      final after = await UserMenuPreferenceService.snapshot('무난함');
      expect(after.removed, isEmpty);
      expect(after.dislikes, isEmpty);
    },
  );
  test(
    'exposure and explicit selection have separate dates and counts',
    () async {
      final first = UserMenuPreferenceService.clock();
      await UserMenuPreferenceService.recordRecommendation('A');
      final before = await UserMenuPreferenceService.snapshot('무난함');
      expect(before.history['A']!.recommendationCount, 1);
      expect(before.selections['A'], 0);
      expect(before.history['A']!.lastSelectedAt, isNull);
      UserMenuPreferenceService.clock = () =>
          first.add(const Duration(minutes: 5));
      await UserMenuPreferenceService.recordSelection('A');
      final after = await UserMenuPreferenceService.snapshot('무난함');
      expect(after.history['A']!.lastRecommendedAt, first);
      expect(
        after.history['A']!.lastSelectedAt,
        first.add(const Duration(minutes: 5)),
      );
      expect(after.selections['A'], 1);
      UserMenuPreferenceService.scopeProvider = () => 'bob';
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).history,
        isEmpty,
      );
    },
  );
  test(
    'history retains concurrent events and their initiating account',
    () async {
      final pending = Future.wait([
        for (int i = 0; i < 10; i++)
          UserMenuPreferenceService.recordRecommendation('A'),
        for (int i = 0; i < 10; i++)
          UserMenuPreferenceService.recordSelection('A'),
      ]);
      UserMenuPreferenceService.scopeProvider = () => 'bob';
      await pending;
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).history,
        isEmpty,
      );
      UserMenuPreferenceService.scopeProvider = () => 'alice';
      final history = (await UserMenuPreferenceService.snapshot(
        '무난함',
      )).history['A']!;
      expect(history.recommendationCount, 10);
      expect(history.selectionCount, 10);
    },
  );
  test(
    'legacy account counts upgrade without invented recency or data loss',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bap_pool_v2_alice_selections', '{"A":4,"B":2}');
      expect(
        (await UserMenuPreferenceService.snapshot('무난함')).selections['A'],
        4,
      );
      await UserMenuPreferenceService.recordRecommendation('B');
      await UserMenuPreferenceService.recordSelection('A');
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.selections, {'A': 5, 'B': 2});
      expect(snapshot.history['B']!.lastSelectedAt, isNull);
      expect(prefs.getString('bap_pool_v2_alice_selections'), '{"A":4,"B":2}');
    },
  );
  test(
    'corrupt history and invalid count values do not block recommendations',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'bap_pool_v2_alice_interaction_history',
        'invalid json',
      );
      await prefs.setString(
        'bap_pool_v2_alice_selections',
        '{"good":2,"bad":"x","negative":-1}',
      );
      expect((await UserMenuPreferenceService.snapshot('무난함')).selections, {
        'good': 2,
      });
      await UserMenuPreferenceService.recordRecommendation('A');
      expect(
        (await UserMenuPreferenceService.snapshot(
          '무난함',
        )).history['A']!.recommendationCount,
        1,
      );
      await prefs.setString(
        'bap_pool_v2_alice_interaction_history',
        '{"A":{"lastSelectedAt":99999999999999999,"selectionCount":-1},"B":false}',
      );
      final snapshot = await UserMenuPreferenceService.snapshot('무난함');
      expect(snapshot.history['A']!.lastSelectedAt, isNull);
      expect(snapshot.history['A']!.selectionCount, 0);
      expect(snapshot.history.containsKey('B'), isFalse);
    },
  );
  test(
    'explicit mood re-add and reset restore eligibility only in that mood',
    () async {
      await UserMenuPreferenceService.dislikeMenuForMood(
        mood: '무난함',
        menuId: 'A',
      );
      await UserMenuPreferenceService.dislikeMenuForMood(
        mood: '피곤함',
        menuId: 'A',
      );
      await UserMenuPreferenceService.removeMoodForMenu(
        mood: '무난함',
        menuId: 'A',
      );
      await UserMenuPreferenceService.addMoodForMenu(mood: '무난함', menuId: 'A');
      final restored = await UserMenuPreferenceService.snapshot('무난함');
      expect(restored.dislikes, isEmpty);
      expect(restored.removed, isEmpty);
      expect(restored.added, {'A'});
      expect((await UserMenuPreferenceService.snapshot('피곤함')).dislikes, {'A'});
    },
  );
}
