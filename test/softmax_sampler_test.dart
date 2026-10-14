import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/models/menu_model.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/softmax_sampler.dart';
import 'package:bp2/services/recommendation_engine.dart';

RankedMenu candidate(
  String id,
  int score, {
  bool explore = false,
  int seen = 0,
}) => RankedMenu(
  MenuModel(
    menuId: id,
    menuName: id,
    category: '한식',
    recommendText: '',
    budgetMin: 5000,
    budgetMax: 10000,
    spicyLevel: '순함',
    moodTags: const ['무난함'],
    situationTags: const ['혼밥'],
  ),
  {'test': score},
  const [],
  explorationEligible: explore,
  exposureCount: seen,
);

class FixedRandom implements Random {
  final double value;
  FixedRandom(this.value);
  @override
  double nextDouble() => value;
  @override
  bool nextBool() => throw UnsupportedError('This test only uses nextDouble');
  @override
  int nextInt(int max) =>
      throw UnsupportedError('This test only uses nextDouble');
}

void main() {
  final sampler = SoftmaxSampler();
  test(
    'exploration reserves a real chance for the least exposed eligible menu',
    () {
      final pool = [
        candidate('frequent', 1000000, explore: true, seen: 20),
        candidate('new', -1000000, explore: true),
        candidate('blocked', -1000000),
      ];
      final probabilities = sampler.distribution(pool, explorationRate: 0.1);
      expect(probabilities.map((p) => p.probability), [0.9, 0.1, 0.0]);
      expect(
        sampler
            .draw(pool, explorationRate: 0.1, random: FixedRandom(0.95))
            .menu
            .menuId,
        'new',
      );
      expect(
        sampler
            .draw(pool, explorationRate: 0.1, random: FixedRandom(0.5))
            .menu
            .menuId,
        'frequent',
      );
    },
  );
  test(
    'exploration ties share mass and absent eligible targets keep pure Softmax',
    () {
      final pool = [
        candidate('a', 0, explore: true),
        candidate('b', 0, explore: true),
        candidate('c', 0, explore: true, seen: 5),
      ];
      final result = sampler.distribution(pool, explorationRate: 1);
      expect(result.map((p) => p.probability), [0.5, 0.5, 0.0]);
      final blocked = [candidate('a', 50), candidate('b', 10)];
      expect(
        sampler
            .distribution(blocked, explorationRate: 0.1)
            .map((p) => p.probability),
        sampler.distribution(blocked).map((p) => p.probability),
      );
      for (final value in [-0.1, 1.1, double.nan, double.infinity]) {
        expect(
          () => sampler.distribution(pool, explorationRate: value),
          throwsArgumentError,
        );
      }
    },
  );
  test('60, 50, 40 yields the proposed probability distribution', () {
    final probabilities = sampler.distribution([
      candidate('A', 60),
      candidate('B', 50),
      candidate('C', 40),
    ]);
    expect(probabilities.map((p) => p.probability).toList(), [
      closeTo(0.6652409558, 1e-9),
      closeTo(0.2447284711, 1e-9),
      closeTo(0.0900305732, 1e-9),
    ]);
    expect(
      probabilities.fold(0.0, (sum, entry) => sum + entry.probability),
      closeTo(1, 1e-12),
    );
  });
  test(
    'all-negative scores and a common score offset give identical probabilities',
    () {
      final positive = sampler.distribution([
        candidate('A', 60),
        candidate('B', 50),
      ]);
      final negative = sampler.distribution([
        candidate('A', -40),
        candidate('B', -50),
      ]);
      for (int i = 0; i < positive.length; i++) {
        expect(negative[i].probability, positive[i].probability);
      }
    },
  );
  test('equal scores get equal probabilities independent of list order', () {
    final result = sampler.distribution([
      candidate('B', 10),
      candidate('A', 10),
      candidate('C', 10),
    ]);
    for (final entry in result) {
      expect(entry.probability, closeTo(1 / 3, 1e-12));
    }
  });
  test('draw follows probability intervals including the lower-score tail', () {
    final pool = [candidate('A', 60), candidate('B', 50), candidate('C', 40)];
    expect(sampler.draw(pool, random: FixedRandom(0)).menu.menuId, 'A');
    expect(sampler.draw(pool, random: FixedRandom(0.7)).menu.menuId, 'B');
    expect(sampler.draw(pool, random: FixedRandom(0.999999)).menu.menuId, 'C');
  });
  test('dislike reduces weight by exp(-6) without removing the candidate', () {
    const request = RecommendationRequest(
      mood: '무난함',
      situation: '혼밥',
      budget: 10000,
    );
    final ranked = RecommendationEngine().rank(
      [candidate('A', 0).menu, candidate('B', 0).menu],
      request,
      preferences: const RecommendationPreferences(dislikes: {'A'}),
    );
    final chances = sampler.distribution(ranked);
    final disliked = chances
        .singleWhere((p) => p.candidate.menu.menuId == 'A')
        .probability;
    final other = chances
        .singleWhere((p) => p.candidate.menu.menuId == 'B')
        .probability;
    expect(disliked / other, closeTo(exp(-6), 1e-12));
    expect(disliked, greaterThan(0));
    expect(
      sampler.draw(ranked, random: FixedRandom(0.999999)).menu.menuId,
      'A',
    );
  });
  test(
    'explicit exclusion still wins over all positive scores and draw chance',
    () {
      final ranked = RecommendationEngine().rank(
        [candidate('A', 0).menu, candidate('B', 0).menu],
        const RecommendationRequest(
          mood: '무난함',
          situation: '혼밥',
          budget: 10000,
        ),
        preferences: const RecommendationPreferences(
          removed: {'A'},
          favorites: {'A'},
          added: {'A'},
          selections: {'A': 100},
        ),
      );
      expect(sampler.distribution(ranked).single.candidate.menu.menuId, 'B');
      expect(
        sampler.draw(ranked, random: FixedRandom(0.999999)).menu.menuId,
        'B',
      );
    },
  );
  test(
    'large score gaps never overflow or fall back to a zero-weight candidate',
    () {
      final pool = [candidate('A', 1000000), candidate('B', -1000000)];
      final distribution = sampler.distribution(pool);
      expect(distribution.map((p) => p.probability), [1.0, 0.0]);
      expect(
        sampler.draw(pool, random: FixedRandom(0.999999)).menu.menuId,
        'A',
      );
    },
  );
  test('no candidates and one negative-scored candidate are explicit', () {
    expect(sampler.distribution([]), isEmpty);
    expect(() => sampler.draw([]), throwsA(isA<NoRecommendationException>()));
    final pool = [candidate('only', -100)];
    expect(sampler.distribution(pool).single.probability, 1);
    expect(sampler.draw(pool).menu.menuId, 'only');
  });
  test(
    'invalid temperatures are rejected and larger temperature increases diversity',
    () {
      final pool = [candidate('A', 60), candidate('B', 40)];
      for (final temperature in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => sampler.distribution(pool, temperature: temperature),
          throwsArgumentError,
        );
      }
      expect(
        sampler.distribution(pool, temperature: 20).last.probability,
        greaterThan(
          sampler.distribution(pool, temperature: 10).last.probability,
        ),
      );
    },
  );
  test(
    'seeded draws reproduce the expected frequency without changing the pool',
    () {
      final pool = [candidate('A', 60), candidate('B', 50), candidate('C', 40)];
      final rng = Random(42);
      final counts = {'A': 0, 'B': 0, 'C': 0};
      for (int i = 0; i < 12000; i++) {
        final id = sampler.draw(pool, random: rng).menu.menuId;
        counts[id] = counts[id]! + 1;
      }
      for (final probability in sampler.distribution(pool)) {
        expect(
          counts[probability.candidate.menu.menuId]! / 12000,
          closeTo(probability.probability, 0.02),
        );
      }
      expect(pool.map((p) => p.menu.menuId), ['A', 'B', 'C']);
      final first = sampler.draw(pool, random: Random(7));
      expect(
        sampler.draw(pool, random: Random(7)).menu.menuId,
        first.menu.menuId,
      );
    },
  );
}
