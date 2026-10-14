import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/models/learning_model.dart';
import 'package:bp2/models/menu_model.dart';
import 'package:bp2/models/food_traits.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/feedback_learning_engine.dart';
import 'package:bp2/services/recommendation_engine.dart';

MenuModel example(
  String id,
  String name,
  String category, {
  int price = 9000,
  String spicy = '순함',
  List<String> moods = const [],
  List<String> situations = const [],
}) => MenuModel(
  menuId: id,
  menuName: name,
  foodTraits: FoodTraits(
    mainIngredients: category == '한식' ? ['콩·두부'] : ['채소'],
    cookingMethod: category == '한식' ? '끓임' : '생식',
    foodForm: category == '한식' ? '국물' : '샐러드',
    tasteTags: ['짭짤함'],
  ),
  category: category,
  budgetMin: 5000,
  budgetMax: price,
  spicyLevel: spicy,
  recommendText: '예시',
  moodTags: moods,
  situationTags: situations,
);
const context = RecommendationRequest(
  mood: '스트레스',
  situation: '혼밥',
  budget: 10000,
);
List<Map<String, dynamic>> samples() => [
  for (var i = 0; i < 24; i++)
    {
      'menuId': 'train-${i % 6}',
      'liked': i.isEven,
      'disliked': i.isOdd,
      'features': FeedbackLearningEngine.features(
        i.isEven ? example('s$i', '두부찌개', '한식') : example('a$i', '샐러드', '양식'),
        context,
      ),
    },
];

void main() {
  test(
    'mood interactions can learn opposite preferences for the same menu',
    () {
      const calm = RecommendationRequest(
        mood: '무난함',
        situation: '혼밥',
        budget: 10000,
      );
      final soup = example('A', '두부찌개', '한식');
      final salad = example('B', '샐러드', '양식');
      final events = <Map<String, dynamic>>[];
      for (var i = 0; i < 16; i++) {
        for (final pair in [
          (soup, context, true),
          (salad, context, false),
          (soup, calm, false),
          (salad, calm, true),
        ]) {
          events.add({
            'menuId': '${pair.$1.menuId}$i',
            'features': FeedbackLearningEngine.features(pair.$1, pair.$2),
            'liked': pair.$3,
            'disliked': !pair.$3,
          });
        }
      }
      final model = FeedbackLearningEngine.fit(events);
      final stressScore = FeedbackLearningEngine.predict(
        model.weights,
        FeedbackLearningEngine.features(soup, context),
      );
      final calmScore = FeedbackLearningEngine.predict(
        model.weights,
        FeedbackLearningEngine.features(soup, calm),
      );
      expect(stressScore, greaterThan(0.5));
      expect(calmScore, lessThan(0.5));
    },
  );

  test(
    'disabled learning reproduces the rules-only baseline despite fitted data',
    () {
      final menus = [example('A', '샐러드', '양식'), example('B', '두부찌개', '한식')];
      final baseline = RecommendationEngine().rank(menus, context);
      final disabled = RecommendationEngine().rank(
        menus,
        context,
        learningEnabled: false,
        preferences: RecommendationPreferences(
          learning: FeedbackLearningEngine.fit(samples()),
        ),
      );
      expect(disabled.map((r) => r.score), baseline.map((r) => r.score));
      expect(
        disabled.map((r) => r.menu.menuId),
        baseline.map((r) => r.menu.menuId),
      );
      expect(disabled.every((r) => !r.learnedModelActive), isTrue);
    },
  );
  test('features are stable, bounded and independent of menu identity', () {
    final first = FeedbackLearningEngine.features(
      example('A', '두부찌개', '한식'),
      context,
    );
    final unseen = FeedbackLearningEngine.features(
      example('new', '버섯찌개', '한식'),
      context,
    );
    expect(first, unseen);
    expect(FeedbackLearningEngine.validFeatures(first), isTrue);
    expect(
      FeedbackLearningEngine.validFeatures(
        List.filled(LearningProfile.dimension, 1.0),
      ),
      isFalse,
    );
    expect(FeedbackLearningEngine.validFeatures([double.nan]), isFalse);
  });

  test('SGD reduces held-out log loss and generalizes to unseen menu IDs', () {
    final profile = FeedbackLearningEngine.fit(samples());
    final positive = FeedbackLearningEngine.predict(
      profile.weights,
      FeedbackLearningEngine.features(
        example('unseen-soup', '버섯찌개', '한식'),
        context,
      ),
    );
    final negative = FeedbackLearningEngine.predict(
      profile.weights,
      FeedbackLearningEngine.features(
        example('unseen-salad', '채소샐러드', '양식'),
        context,
      ),
    );
    expect(profile.ready, isTrue);
    expect(positive, greaterThan(0.6));
    expect(negative, lessThan(0.4));
    expect((-log(positive) - log(1 - negative)) / 2, lessThan(log(2)));
    expect(FeedbackLearningEngine.fit(samples()).weights, profile.weights);
    expect(LearningProfile.fromMap(profile.toMap()).weights, profile.weights);
  });

  test('insufficient feedback and repeated single-menu data keep baseline', () {
    for (final events in [
      samples().take(3).toList(),
      samples().map((s) => {...s, 'menuId': 'same'}).toList(),
    ]) {
      final profile = FeedbackLearningEngine.fit(events);
      expect(profile.ready, isFalse);
      expect(
        FeedbackLearningEngine.adjustment(
          profile,
          FeedbackLearningEngine.features(example('A', '두부찌개', '한식'), context),
        ),
        0,
      );
    }
  });

  test('no response and withdrawn like are never negative training labels', () {
    final profile = FeedbackLearningEngine.fit([
      {'menuId': 'A', 'features': List.filled(LearningProfile.dimension, 0.0)},
      {
        'menuId': 'B',
        'features': List.filled(LearningProfile.dimension, 0.0),
        'liked': false,
      },
    ]);
    expect(profile.sampleCount, 0);
    expect(profile.weights.every((w) => w == 0), isTrue);
    expect(FeedbackLearningEngine.label({'liked': true, 'selected': true}), 1);
    expect(
      FeedbackLearningEngine.label({
        'liked': true,
        'selected': true,
        'disliked': true,
      }),
      0,
    );
  });

  test(
    'one-sided feedback applies a small bonus without invented negatives',
    () {
      for (final liked in [true, false]) {
        final model = FeedbackLearningEngine.fit([
          for (var i = 0; i < 8; i++)
            {
              'menuId': 'M$i',
              'features': FeedbackLearningEngine.features(
                example('M$i', '두부찌개', '한식'),
                context,
              ),
              'liked': liked,
              'disliked': !liked,
            },
        ]);
        expect(model.ready, isTrue);
        expect(model.hasStrongFeedback, isFalse);
        expect(model.mixedConfidence, 0);
        final score = FeedbackLearningEngine.adjustment(
          model,
          FeedbackLearningEngine.features(
            example('new', '버섯찌개', '한식'),
            context,
          ),
        );
        expect(liked ? score : -score, inInclusiveRange(1, 6));
        expect(
          FeedbackLearningEngine.adjustment(
            model,
            List.filled(LearningProfile.dimension, 0.0),
          ),
          0,
        );
        expect(LearningProfile.fromMap(model.toMap()).ready, isTrue);
        expect(model.positives, liked ? 8 : 0);
        expect(model.negatives, liked ? 0 : 8);
      }
    },
  );

  test('small mixed feedback does not yet weaken generic tag matches', () {
    final model = FeedbackLearningEngine.fit(samples().take(4).toList());
    expect(model.ready, isTrue);
    expect(model.hasStrongFeedback, isFalse);
    expect(model.mixedConfidence, 0);
    final result = RecommendationEngine().rank(
      [
        example('unseen', '두부찌개', '한식', moods: ['스트레스'], situations: ['혼밥']),
      ],
      context,
      preferences: RecommendationPreferences(learning: model),
    );
    expect(result.single.contributions['mood'], 30);
    expect(result.single.contributions['situation'], 25);
    expect(
      (result.single.contributions['learnedPreference'] ?? 0).abs(),
      lessThanOrEqualTo(3),
    );
  });

  test(
    'strong personal evidence can outrank generic tags without changing explicit preferences',
    () {
      final model = FeedbackLearningEngine.fit([
        ...samples(),
        ...samples().map((e) => {...e, 'menuId': '${e['menuId']}-repeat'}),
      ]);
      final pool = [
        example('salad', '채소샐러드', '양식', moods: ['스트레스'], situations: ['혼밥']),
        example('soup', '버섯찌개', '한식'),
      ];
      expect(
        RecommendationEngine().rank(pool, context).first.menu.menuId,
        'salad',
      );
      final personalized = RecommendationEngine().rank(
        pool,
        context,
        preferences: RecommendationPreferences(learning: model),
      );
      expect(personalized.first.menu.menuId, 'soup');
      final salad = personalized.singleWhere((r) => r.menu.menuId == 'salad');
      expect(salad.contributions['mood'], 12);
      expect(salad.contributions['situation'], 10);
      final explicit = RecommendationEngine().rank(
        pool,
        context,
        preferences: RecommendationPreferences(
          learning: model,
          favorites: {'soup'},
          dislikes: {'soup'},
        ),
      );
      final soup = explicit.singleWhere((r) => r.menu.menuId == 'soup');
      expect(soup.contributions['favorite'], 20);
      expect(soup.contributions['dislike'], -60);
      expect(soup.explorationEligible, isFalse);
      final custom = RecommendationEngine().rank(
        pool,
        context,
        preferences: RecommendationPreferences(
          learning: model,
          added: {'salad'},
        ),
      );
      final added = custom.singleWhere((r) => r.menu.menuId == 'salad');
      expect(added.contributions['mood'], 30);
      expect(added.contributions['customMood'], 15);
      expect(
        FeedbackLearningEngine.adjustment(
          model,
          FeedbackLearningEngine.features(pool.last, context),
        ).abs(),
        lessThanOrEqualTo(30),
      );
    },
  );

  test('learning cannot override hard constraints or cancel -60 dislike', () {
    final profile = FeedbackLearningEngine.fit(samples());
    final result = RecommendationEngine().rank(
      [
        example('ok', '버섯찌개', '한식'),
        example('expensive', '두부찌개', '한식', price: 10001),
        example('hot', '두부찌개', '한식', spicy: '매움'),
        example('removed', '두부찌개', '한식'),
      ],
      const RecommendationRequest(
        mood: '스트레스',
        situation: '혼밥',
        budget: 10000,
        spicy: '순함',
      ),
      preferences: RecommendationPreferences(
        learning: profile,
        dislikes: {'ok'},
        removed: {'removed'},
      ),
    );
    expect(result.map((r) => r.menu.menuId), ['ok']);
    expect(result.single.contributions['dislike'], -60);
    expect(
      result.single.contributions['learnedPreference']!.abs(),
      lessThanOrEqualTo(30),
    );
    expect(result.single.score, lessThan(0));
  });

  test('invalid parameters and unsupported model versions are rejected', () {
    final valid = FeedbackLearningEngine.fit(samples()).toMap();
    for (final patch in [
      {'version': 99},
      {
        'weights': [double.nan],
      },
      {'sampleCount': -1},
      {'positives': 0},
    ]) {
      expect(
        () => LearningProfile.fromMap({...valid, ...patch}),
        throwsFormatException,
      );
    }
    expect(
      () => FeedbackLearningEngine.predict([
        double.infinity,
      ], List.filled(LearningProfile.dimension, 0.0)),
      throwsArgumentError,
    );
  });

  test('ready model changes ordering of equally scored unseen candidates', () {
    final baseline = RecommendationEngine().rank([
      example('A-salad', '채소샐러드', '양식'),
      example('Z-soup', '버섯찌개', '한식'),
    ], context);
    final hybrid = RecommendationEngine().rank(
      baseline.map((r) => r.menu).toList(),
      context,
      preferences: RecommendationPreferences(
        learning: FeedbackLearningEngine.fit(samples()),
      ),
    );
    expect(baseline.first.menu.menuId, 'A-salad');
    expect(hybrid.first.menu.menuId, 'Z-soup');
    expect(hybrid.first.learnedModelActive, isTrue);
    expect(hybrid.first.reasons.any((reason) => reason.contains('학습')), isTrue);
  });
}
