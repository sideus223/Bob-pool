import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:bp2/models/menu_model.dart';
import 'package:bp2/models/learning_model.dart';
import 'package:bp2/models/learning_feature_schema.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/feedback_learning_engine.dart';
import 'package:bp2/services/recommendation_engine.dart';
import 'package:bp2/services/softmax_sampler.dart';

// Reproducible mechanical evaluation only. Labels are synthetic, not users.
void main() {
  final rows =
      jsonDecode(File('assets/data/menus_dataset.json').readAsStringSync())
          as List;
  final menus = rows
      .map((row) => MenuModel.fromMap(Map<String, dynamic>.from(row)))
      .toList();
  const request = RecommendationRequest(
    mood: '스트레스',
    situation: '혼밥',
    budget: 25000,
  );
  final eligible =
      RecommendationEngine().rank(menus, request).map((r) => r.menu).toList()
        ..sort((a, b) => a.menuId.compareTo(b.menuId));
  final reports = <Map<String, dynamic>>[];
  for (final scenario in [
    'soup',
    'western',
    'stir_fry',
    'pork_over_seafood',
    'grilled_over_fried',
  ]) {
    bool positive(MenuModel menu) => switch (scenario) {
      'soup' => menu.foodTraits.foodForm == '국물',
      'western' => menu.category == '양식',
      'stir_fry' => menu.foodTraits.cookingMethod == '볶음',
      'pork_over_seafood' => menu.foodTraits.mainIngredients.contains('돼지고기'),
      _ => menu.foodTraits.cookingMethod == '구이',
    };
    final pool = eligible
        .where(
          (menu) => switch (scenario) {
            'pork_over_seafood' =>
              menu.foodTraits.mainIngredients.contains('돼지고기') !=
                  menu.foodTraits.mainIngredients.contains('해산물'),
            'grilled_over_fried' => [
              '구이',
              '튀김',
            ].contains(menu.foodTraits.cookingMethod),
            _ => true,
          },
        )
        .toList();
    final train = <MenuModel>[];
    final test = <MenuModel>[];
    for (var i = 0; i < pool.length; i++) {
      (i % 3 == 0 ? test : train).add(pool[i]);
    }
    final samples = train
        .take(64)
        .map(
          (menu) => <String, dynamic>{
            'menuId': menu.menuId,
            'features': FeedbackLearningEngine.features(menu, request),
            'liked': positive(menu),
            'disliked': !positive(menu),
          },
        )
        .toList();
    final model = FeedbackLearningEngine.fit(samples);
    final prior =
        samples.where((s) => s['liked'] == true).length / samples.length;
    double loss(double p, bool label) =>
        -log((label ? p : 1 - p).clamp(1e-9, 1.0));
    final baselineLoss =
        test.map((menu) => loss(0.5, positive(menu))).reduce((a, b) => a + b) /
        test.length;
    final learnedLoss =
        test
            .map(
              (menu) => loss(
                FeedbackLearningEngine.predict(
                  model.weights,
                  FeedbackLearningEngine.features(menu, request),
                ),
                positive(menu),
              ),
            )
            .reduce((a, b) => a + b) /
        test.length;
    final priorLoss =
        test
            .map((menu) => loss(prior, positive(menu)))
            .reduce((a, b) => a + b) /
        test.length;
    double balancedLoss(double Function(MenuModel) prediction) {
      final positives = test.where(positive).toList();
      final negatives = test.where((menu) => !positive(menu)).toList();
      if (positives.isEmpty || negatives.isEmpty) return double.nan;
      double average(List<MenuModel> group, bool target) =>
          group
              .map((menu) => loss(prediction(menu), target))
              .reduce((a, b) => a + b) /
          group.length;
      return (average(positives, true) + average(negatives, false)) / 2;
    }

    double favorableDrawMass(RecommendationPreferences preferences) {
      final ranked = RecommendationEngine().rank(
        test,
        request,
        preferences: preferences,
      );
      return SoftmaxSampler()
          .distribution(
            ranked,
            explorationRate: SoftmaxSampler.defaultExplorationRate,
          )
          .where((entry) => positive(entry.candidate.menu))
          .fold(0.0, (sum, entry) => sum + entry.probability);
    }

    reports.add({
      'scenario': scenario,
      'syntheticLabels': true,
      'trainCount': samples.length,
      'heldOutMenuCount': test.length,
      'trainMenuIds': samples.map((s) => s['menuId']).toList(),
      'heldOutMenuIds': test.map((m) => m.menuId).toList(),
      'modelReady': model.ready,
      'neutralBaselineLogLoss': baselineLoss,
      'classPriorBaselineLogLoss': priorLoss,
      'learnedLogLoss': learnedLoss,
      'balancedClassPriorLogLoss': balancedLoss((_) => prior),
      'balancedLearnedLogLoss': balancedLoss(
        (menu) => FeedbackLearningEngine.predict(
          model.weights,
          FeedbackLearningEngine.features(menu, request),
        ),
      ),
      'strongestFeatures': [
        ...(List.generate(LearningProfile.dimension, (index) => index)..sort(
              (a, b) =>
                  model.weights[b].abs().compareTo(model.weights[a].abs()),
            ))
            .take(8)
            .map(
              (i) => {
                'feature': LearningFeatureSchema.keys[i],
                'weight': model.weights[i],
              },
            ),
      ],
      'rulesFavorableDrawMass': favorableDrawMass(
        const RecommendationPreferences(),
      ),
      'hybridFavorableDrawMass': favorableDrawMass(
        RecommendationPreferences(learning: model),
      ),
    });
  }
  final output = {
    'modelVersion': LearningProfile.version,
    'featureDimension': LearningProfile.dimension,
    'rankingPolicy': 'hybrid-v3',
    'explorationRate': SoftmaxSampler.defaultExplorationRate,
    'dataset': 'assets/data/menus_dataset.json',
    'method':
        'Explicit food traits; deterministic logistic regression; held-out menu IDs; each scenario split independently',
    'limitations':
        'Synthetic labels only. Not measured recommendation accuracy or user satisfaction. No causal/off-policy evaluation.',
    'reports': reports,
  };
  final json = const JsonEncoder.withIndent('  ').convert(output);
  File('docs/learning_evaluation.json').writeAsStringSync('$json\n');
  stdout.writeln(json);
}
