import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/models/menu_model.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/recommendation_engine.dart';

MenuModel menu(
  String id, {
  int max = 10000,
  String spicy = '순함',
  List<String> moods = const ['무난함'],
  List<String> situations = const ['혼밥'],
}) => MenuModel(
  menuId: id,
  menuName: id,
  category: '한식',
  recommendText: '예시',
  budgetMin: 5000,
  budgetMax: max,
  spicyLevel: spicy,
  moodTags: moods,
  situationTags: situations,
);

void main() {
  final engine = RecommendationEngine();
  const request = RecommendationRequest(
    mood: '무난함',
    situation: '혼밥',
    budget: 10000,
    spicy: '순함',
  );
  test('hard constraints override even maximum positive preference scores', () {
    final result = engine.rank(
      [menu('ok'), menu('expensive', max: 10001), menu('hot', spicy: '매움')],
      request,
      preferences: const RecommendationPreferences(
        favorites: {'expensive', 'hot'},
        selections: {'expensive': 100},
      ),
    );
    expect(result.map((r) => r.menu.menuId), ['ok']);
  });
  test('no match stays empty; never silently relaxes budget or spice', () {
    expect(
      engine.rank([
        menu('costly', max: 10001),
        menu('hot', spicy: '매움'),
      ], request),
      isEmpty,
    );
  });
  test('cheaper ranges remain eligible with larger maximum budgets', () {
    expect(
      engine.rank(
        [menu('cheap')],
        const RecommendationRequest(
          mood: '무난함',
          situation: '혼밥',
          budget: 30000,
        ),
      ),
      hasLength(1),
    );
  });
  test(
    'favorite and explicit selections improve ranking with capped history',
    () {
      final result = engine.rank(
        [menu('A'), menu('B')],
        request,
        preferences: const RecommendationPreferences(
          favorites: {'B'},
          selections: {'B': 100},
        ),
      );
      expect(result.first.menu.menuId, 'B');
      expect(result.first.contributions['selection'], 15);
      expect(result.first.score, 90);
    },
  );
  test('negative feedback strongly demotes but preserves eligible menus', () {
    final result = engine.rank(
      [menu('A'), menu('B')],
      request,
      preferences: const RecommendationPreferences(
        dislikes: {'A'},
        favorites: {'A'},
        selections: {'A': 100},
      ),
    );
    expect(result.map((r) => r.menu.menuId), ['B', 'A']);
    expect(result.last.contributions['dislike'], -60);
    expect(
      engine.rank(
        [menu('A')],
        request,
        preferences: const RecommendationPreferences(dislikes: {'A'}),
      ),
      hasLength(1),
    );
  });
  test('removed mood overrides added mood and built-in tags', () {
    final r = engine.rank(
      [menu('A')],
      request,
      preferences: const RecommendationPreferences(
        added: {'A'},
        removed: {'A'},
      ),
    );
    expect(r, isEmpty);
  });
  test('custom mood additions and spaced mood names match', () {
    final r = engine.rank(
      [
        menu('A', moods: const ['기분좋음']),
        menu('B', moods: const []),
      ],
      const RecommendationRequest(
        mood: '기분 좋음',
        situation: '혼밥',
        budget: 10000,
      ),
      preferences: const RecommendationPreferences(added: {'B'}),
    );
    expect(r.first.menu.menuId, 'B');
    expect(r.last.contributions['mood'], 30);
  });
  test('ties are deterministic and source order remains unchanged', () {
    final source = [menu('B'), menu('A')];
    expect(engine.rank(source, request).map((r) => r.menu.menuId), ['A', 'B']);
    expect(source.first.menuId, 'B');
  });
  test('seen candidates are excluded without fallback repetition', () {
    expect(engine.rank([menu('A')], request, excludedIds: {'A'}), isEmpty);
  });
  final now = DateTime.utc(2026, 10, 11, 12);
  test(
    'exploration avoids disliked and recently shown or selected menus while preserving constraints',
    () {
      final result = engine.rank(
        [
          menu('new'),
          menu('disliked'),
          menu('shown'),
          menu('chosen'),
          menu('too-expensive', max: 10001),
          menu('hot', spicy: '매움'),
        ],
        request,
        now: now,
        preferences: RecommendationPreferences(
          dislikes: {'disliked'},
          history: {
            'shown': MenuInteractionHistory(
              recommendationCount: 2,
              lastRecommendedAt: now,
            ),
            'chosen': MenuInteractionHistory(lastSelectedAt: now),
          },
        ),
      );
      expect(
        result.where((r) => r.explorationEligible).map((r) => r.menu.menuId),
        ['new'],
      );
      expect(
        result.any(
          (r) => r.menu.menuId == 'hot' || r.menu.menuId == 'too-expensive',
        ),
        isFalse,
      );
      expect(
        result.singleWhere((r) => r.menu.menuId == 'shown').exposureCount,
        2,
      );
    },
  );
  test('recent choice outweighs favorites and capped lifetime selections', () {
    final result = engine.rank(
      [menu('A'), menu('B')],
      request,
      now: now,
      preferences: RecommendationPreferences(
        favorites: {'A'},
        selections: {'A': 100},
        history: {'A': MenuInteractionHistory(lastSelectedAt: now)},
      ),
    );
    expect(result.map((r) => r.menu.menuId), ['B', 'A']);
    expect(result.last.contributions['recentSelection'], -50);
    expect(result.last.reasons.any((r) => r.contains('최근 선택')), isTrue);
  });
  test('recency penalties expire at exact 24h, 48h and 7 day boundaries', () {
    RankedMenu ranked(Duration age) => engine
        .rank(
          [menu('A')],
          request,
          now: now,
          preferences: RecommendationPreferences(
            history: {
              'A': MenuInteractionHistory(
                lastRecommendedAt: now.subtract(age),
                lastSelectedAt: now.subtract(age),
              ),
            },
          ),
        )
        .single;
    expect(
      ranked(const Duration(hours: 23)).contributions['recentRecommendation'],
      -20,
    );
    expect(
      ranked(
        const Duration(hours: 24),
      ).contributions.containsKey('recentRecommendation'),
      isFalse,
    );
    expect(
      ranked(const Duration(hours: 47)).contributions['recentSelection'],
      -50,
    );
    expect(
      ranked(const Duration(hours: 48)).contributions['recentSelection'],
      -20,
    );
    expect(
      ranked(
        const Duration(days: 7),
      ).contributions.containsKey('recentSelection'),
      isFalse,
    );
  });
  test('equal scores rotate toward unseen then oldest and least exposed', () {
    final result = engine.rank(
      [menu('A'), menu('B'), menu('C'), menu('D')],
      request,
      now: now,
      preferences: RecommendationPreferences(
        history: {
          'A': MenuInteractionHistory(
            lastRecommendedAt: now.subtract(const Duration(days: 2)),
            recommendationCount: 3,
          ),
          'B': MenuInteractionHistory(
            lastRecommendedAt: now.subtract(const Duration(days: 3)),
            recommendationCount: 5,
          ),
          'D': MenuInteractionHistory(
            lastRecommendedAt: now.subtract(const Duration(days: 3)),
            recommendationCount: 2,
          ),
        },
      ),
    );
    expect(result.map((r) => r.menu.menuId), ['C', 'D', 'B', 'A']);
  });
  test('one eligible recent menu remains available; constraints still win', () {
    final result = engine.rank(
      [menu('A'), menu('costly', max: 10001)],
      request,
      now: now,
      preferences: RecommendationPreferences(
        history: {
          'A': MenuInteractionHistory(
            lastRecommendedAt: now,
            lastSelectedAt: now,
          ),
        },
      ),
    );
    expect(result.single.menu.menuId, 'A');
    expect(result.single.score, -15);
  });
  test('future timestamps do not create lasting recency penalties', () {
    final r = engine
        .rank(
          [menu('A')],
          request,
          now: now,
          preferences: RecommendationPreferences(
            history: {
              'A': MenuInteractionHistory(
                lastRecommendedAt: now.add(const Duration(days: 1)),
                lastSelectedAt: now.add(const Duration(days: 1)),
              ),
            },
          ),
        )
        .single;
    expect(r.score, 55);
  });
  test('invalid price ranges and invalid request budgets are rejected', () {
    expect(engine.rank([menu('bad', max: 4000)], request), isEmpty);
    expect(
      () => engine.rank(
        [],
        const RecommendationRequest(mood: '', situation: '', budget: 0),
      ),
      throwsA(isA<NoRecommendationException>()),
    );
  });
  test(
    'all bundled menus have unique IDs, images and complete recipe content',
    () {
      final rows =
          jsonDecode(File('assets/data/menus_dataset.json').readAsStringSync())
              as List;
      final menus = rows
          .map((r) => MenuModel.fromMap(r as Map<String, dynamic>))
          .toList();
      expect(menus, hasLength(100));
      expect(menus.map((m) => m.menuId).toSet(), hasLength(menus.length));
      for (final m in menus) {
        expect(File(m.imageAssetPath).existsSync(), isTrue, reason: m.menuId);
        expect(m.ingredients, isNotEmpty, reason: m.menuId);
        expect(m.recipeSteps, isNotEmpty, reason: m.menuId);
        expect(m.budgetMin, greaterThan(0));
        expect(m.budgetMax, greaterThanOrEqualTo(m.budgetMin));
      }
      // Exhaustive check over every choice exposed by the current picker.
      for (final mood in ['기분 좋음', '무난함', '우울함', '스트레스', '피곤함']) {
        for (final situation in ['혼밥', '친구랑', '데이트', '든든하게', '가볍게', '빨리먹기']) {
          for (final spicy in ['상관없음', '순함', '보통', '매움']) {
            for (int budget = 5000; budget <= 50000; budget += 1000) {
              final ranked = engine.rank(
                menus,
                RecommendationRequest(
                  mood: mood,
                  situation: situation,
                  budget: budget,
                  spicy: spicy,
                ),
              );
              for (final r in ranked) {
                expect(r.menu.budgetMax <= budget, isTrue);
                expect(spicy == '상관없음' || r.menu.spicyLevel == spicy, isTrue);
              }
            }
          }
        }
      }
    },
  );
}
