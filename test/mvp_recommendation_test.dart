import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:bp2/models/food_traits.dart';
import 'package:bp2/models/learning_feature_schema.dart';
import 'package:bp2/models/learning_model.dart';
import 'package:bp2/models/menu_model.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/feedback_learning_engine.dart';
import 'package:bp2/services/recommendation_engine.dart';
import 'package:bp2/services/softmax_sampler.dart';

const request = RecommendationRequest(
  mood: '스트레스',
  situation: '혼밥',
  budget: 20000,
);
MenuModel dish(
  String id, {
  String ingredient = '돼지고기',
  String method = '볶음',
  String form = '일품',
  int price = 10000,
  String spice = '보통',
}) => MenuModel(
  menuId: id,
  menuName: '이름에 특징이 없는 $id',
  category: '한식',
  budgetMin: 5000,
  budgetMax: price,
  spicyLevel: spice,
  recommendText: '',
  foodTraits: FoodTraits(
    mainIngredients: [ingredient],
    cookingMethod: method,
    foodForm: form,
    tasteTags: ['짭짤함'],
  ),
);
Map<String, dynamic> sample(MenuModel menu, bool liked) => {
  'menuId': menu.menuId,
  'features': FeedbackLearningEngine.features(menu, request),
  'liked': liked,
  'disliked': !liked,
};

void main() {
  test(
    'catalog traits use the fixed vocabulary and preserve recipe round trips',
    () {
      final rows =
          jsonDecode(File('assets/data/menus_dataset.json').readAsStringSync())
              as List;
      expect(rows, hasLength(100));
      for (final row in rows) {
        final menu = MenuModel.fromMap(Map<String, dynamic>.from(row));
        expect(menu.foodTraits.isComplete, isTrue, reason: menu.menuId);
        expect(
          MenuModel.fromMap(menu.toMap()).foodTraits.toMap(),
          menu.foodTraits.toMap(),
        );
        expect(
          FeedbackLearningEngine.validFeatures(
            FeedbackLearningEngine.features(menu, request),
          ),
          isTrue,
        );
      }
      final menus = rows
          .map((r) => MenuModel.fromMap(Map<String, dynamic>.from(r)))
          .toList();
      expect(menus[29].foodTraits.cookingMethod, '볶음'); // 닭갈비
      expect(menus[22].foodTraits.cookingMethod, '볶음'); // 제육볶음
      expect(menus[94].foodTraits.mainIngredients, ['곡물']); // 죽
      expect(
        () => FoodTraits.fromMap({
          'main_ingredients': ['모름'],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'every feature has a unique explicit index and menu names do not change vectors',
    () {
      expect(LearningFeatureSchema.keys, hasLength(LearningProfile.dimension));
      expect(
        LearningFeatureSchema.keys.toSet(),
        hasLength(LearningProfile.dimension),
      );
      final original = dish('A');
      final renamed = MenuModel.fromMap({
        ...original.toMap(),
        'menu_id': 'Z',
        'menu_name': '국 면 샐러드',
      });
      expect(
        FeedbackLearningEngine.features(original, request),
        FeedbackLearningEngine.features(renamed, request),
      );
      final features = FeedbackLearningEngine.features(original, request);
      expect(
        features[LearningFeatureSchema.index['ingredient:돼지고기']!],
        greaterThan(0),
      );
      expect(features[LearningFeatureSchema.index['ingredient:해산물']!], 0);
      expect(
        features[LearningFeatureSchema.index['method:볶음']!],
        greaterThan(0),
      );
      expect(features[LearningFeatureSchema.index['method:튀김']!], 0);
    },
  );

  test(
    'unseen dishes learn ingredient preference within the same cuisine and form',
    () {
      final model = FeedbackLearningEngine.fit([
        for (var i = 0; i < 24; i++)
          sample(
            dish('train-$i', ingredient: i.isEven ? '돼지고기' : '해산물'),
            i.isEven,
          ),
      ]);
      final pork = dish('new-pork');
      final seafood = dish('new-seafood', ingredient: '해산물');
      final positive = FeedbackLearningEngine.predict(
        model.weights,
        FeedbackLearningEngine.features(pork, request),
      );
      final negative = FeedbackLearningEngine.predict(
        model.weights,
        FeedbackLearningEngine.features(seafood, request),
      );
      expect(positive, greaterThan(0.5));
      expect(negative, lessThan(0.5));
      expect(positive - negative, greaterThan(0.1));
      final ranked = RecommendationEngine().rank(
        [seafood, pork],
        request,
        preferences: RecommendationPreferences(learning: model),
      );
      expect(ranked.first.menu.menuId, 'new-pork');
    },
  );

  test(
    'unseen dishes learn cooking method independently of cuisine and main ingredient',
    () {
      final model = FeedbackLearningEngine.fit([
        for (var i = 0; i < 24; i++)
          sample(dish('train-$i', method: i.isEven ? '구이' : '튀김'), i.isEven),
      ]);
      final grilled = dish('new-grilled', method: '구이');
      final fried = dish('new-fried', method: '튀김');
      expect(
        FeedbackLearningEngine.adjustment(
          model,
          FeedbackLearningEngine.features(grilled, request),
        ),
        greaterThan(
          FeedbackLearningEngine.adjustment(
            model,
            FeedbackLearningEngine.features(fried, request),
          ),
        ),
      );
    },
  );

  test('few explicit likes remain learnable amid many dislikes', () {
    final model = FeedbackLearningEngine.fit([
      for (var i = 0; i < 24; i++)
        sample(dish('negative-$i', ingredient: '해산물'), false),
      for (var i = 0; i < 4; i++) sample(dish('positive-$i'), true),
    ]);
    final liked = FeedbackLearningEngine.predict(
      model.weights,
      FeedbackLearningEngine.features(dish('new-pork'), request),
    );
    final disliked = FeedbackLearningEngine.predict(
      model.weights,
      FeedbackLearningEngine.features(
        dish('new-seafood', ingredient: '해산물'),
        request,
      ),
    );
    expect(liked, greaterThan(0.5));
    expect(disliked, lessThan(0.5));
    expect(model.weights.every((w) => w.isFinite && w.abs() <= 4), isTrue);
  });

  test(
    'similar meals receive a soft penalty even when the previous menu is filtered out',
    () {
      final now = DateTime.utc(2026, 10, 13, 12);
      final menus = [
        dish('old', form: '면'),
        dish('noodle', form: '면'),
        dish('rice', form: '밥'),
      ];
      final preferences = RecommendationPreferences(
        history: {
          'old': MenuInteractionHistory(
            lastRecommendedAt: now.subtract(const Duration(minutes: 1)),
          ),
        },
      );
      final ranked = RecommendationEngine().rank(
        menus,
        request,
        preferences: preferences,
        excludedIds: {'old'},
        now: now,
      );
      expect(ranked.map((r) => r.menu.menuId), ['rice', 'noodle']);
      expect(ranked.last.contributions['similarRecentMenu'], -12);
      expect(ranked.last.explorationEligible, isFalse);
      final distribution = SoftmaxSampler().distribution(
        ranked,
        explorationRate: 0.1,
      );
      expect(
        distribution.first.probability,
        greaterThan(distribution.last.probability),
      );
      final onlySimilar = RecommendationEngine().rank(
        menus,
        request,
        preferences: preferences,
        excludedIds: {'old', 'rice'},
        now: now,
      );
      expect(
        SoftmaxSampler().draw(onlySimilar, random: Random(7)).menu.menuId,
        'noodle',
      );
    },
  );

  test(
    'diversity ignores stale or future history and never reintroduces forbidden dishes',
    () {
      final now = DateTime.utc(2026, 10, 13, 12);
      final menus = [
        dish('old', form: '면'),
        dish('noodle', form: '면'),
        dish('expensive', price: 30000),
        dish('spicy', spice: '매움'),
        dish('removed'),
      ];
      for (final time in [
        now.add(const Duration(hours: 1)),
        now.subtract(const Duration(days: 1)),
      ]) {
        final ranked = RecommendationEngine().rank(
          menus,
          const RecommendationRequest(
            mood: '스트레스',
            situation: '혼밥',
            budget: 20000,
            spicy: '보통',
          ),
          preferences: RecommendationPreferences(
            removed: {'removed'},
            history: {'old': MenuInteractionHistory(lastRecommendedAt: time)},
          ),
          excludedIds: {'old'},
          now: now,
        );
        expect(ranked.single.menu.menuId, 'noodle');
        expect(
          ranked.single.contributions.containsKey('similarRecentMenu'),
          isFalse,
        );
      }
    },
  );

  test(
    'legacy unknown and expired menu reactions are not invented as new training data',
    () {
      final now = DateTime.utc(2026, 10, 13, 12);
      Map<String, dynamic> event(String id, String menuId, DateTime created) =>
          RecommendationExposure(
            id: id,
            scope: 'alice',
            menuId: menuId,
            mood: request.mood,
            situation: request.situation,
            budget: request.budget,
            spicy: request.spicy,
            features: List.filled(64, 0.0),
            candidateIds: [menuId],
            drawProbability: 1,
            score: 0,
            learned: false,
            createdAt: created.millisecondsSinceEpoch,
          ).toMap()..remove('featureVersion');
      final raw = {
        'version': 1,
        'weights': List.filled(64, 0.0),
        'sampleCount': 0,
        'positives': 0,
        'negatives': 0,
        'distinctMenus': 0,
        'events': [
          event('known', 'A', now),
          event('unknown', 'missing', now),
          event('expired', 'A', now.subtract(const Duration(days: 31))),
        ],
      };
      expect(LearningProfile.fromMap(raw).ready, isFalse);
      expect(
        () => FeedbackLearningEngine.events(raw, now),
        throwsFormatException,
      );
      final migrated = FeedbackLearningEngine.events(
        raw,
        now,
        catalog: {'A': dish('A')},
      );
      expect(migrated.map((e) => e['id']), ['known']);
      expect(migrated.single['features'], hasLength(LearningProfile.dimension));
      expect(FeedbackLearningEngine.state(migrated)['version'], 2);
      expect(raw['version'], 1);
    },
  );
}
