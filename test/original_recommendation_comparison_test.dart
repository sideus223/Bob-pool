import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/models/menu_model.dart';
import 'package:bp2/models/recommendation_model.dart';
import 'package:bp2/services/feedback_learning_engine.dart';
import 'package:bp2/services/recommendation_diversity.dart';
import 'package:bp2/services/recommendation_engine.dart';
import 'package:bp2/services/softmax_sampler.dart';
// Import the unmodified original snapshot, outside the app's lib directory.
// ignore: avoid_relative_lib_imports
import '../tools/evaluation_baselines/original/lib/services/local_recommend_service.dart'
    as original;

const drawsPerRun = 100;
const repetitions = 20;
const preferenceDraws = 2000;
final epoch = DateTime.utc(2026, 10, 13);
final engine = RecommendationEngine();
final sampler = SoftmaxSampler();
double mean(Iterable<num> values) =>
    values.fold(0.0, (a, b) => a + b) / values.length;

List<MenuProbability> currentDistribution(
  List<MenuModel> menus,
  RecommendationRequest request,
  RecommendationPreferences preferences, {
  DateTime? now,
}) {
  final ranked = engine.rank(
    menus,
    request,
    preferences: preferences,
    now: now ?? epoch,
  );
  final entries = sampler.distribution(ranked, explorationRate: 0.1);
  expect(entries, isNotEmpty);
  expect(entries.fold(0.0, (sum, e) => sum + e.probability), closeTo(1, 1e-9));
  expect(
    entries.every((e) => e.candidate.menu.budgetMax <= request.budget),
    isTrue,
  );
  return entries;
}

MenuModel draw(List<MenuProbability> entries, Random random) {
  final target = random.nextDouble();
  var cumulative = 0.0;
  for (final entry in entries) {
    cumulative += entry.probability;
    if (target < cumulative) return entry.candidate.menu;
  }
  return entries.last.candidate.menu;
}

class SequenceMetrics {
  final ids = <String>{};
  final forms = <String>{};
  final counts = <String, int>{};
  MenuModel? previous;
  int identical = 0, similar = 0, overBudget = 0, count = 0;

  void add(MenuModel menu, int budget) {
    ids.add(menu.menuId);
    forms.add(menu.foodTraits.foodForm);
    counts.update(menu.menuId, (value) => value + 1, ifAbsent: () => 1);
    if (previous != null) {
      if (previous!.menuId == menu.menuId) identical++;
      if (previous!.menuId == menu.menuId ||
          RecommendationDiversity.similar(menu, previous)) {
        similar++;
      }
    }
    if (menu.budgetMax > budget) overBudget++;
    previous = menu;
    count++;
  }

  Map<String, num> summary() => {
    'uniqueMenus': ids.length,
    'uniqueForms': forms.length,
    'identicalRepeatRate': identical / (count - 1),
    'similarRepeatRate': similar / (count - 1),
    'overBudgetRate': overBudget / count,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'compare unchanged desktop original with current local recommendation',
    () async {
      final oldJson = File(
        'tools/evaluation_baselines/original/assets/data/menus_dataset.json',
      ).readAsStringSync();
      final currentRows =
          jsonDecode(File('assets/data/menus_dataset.json').readAsStringSync())
              as List;
      final oldRows = jsonDecode(oldJson) as List;
      final menus = currentRows
          .map((row) => MenuModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      final byId = {for (final menu in menus) menu.menuId: menu};
      expect(menus.length, 100);
      expect(byId.length, 100);
      expect(oldRows.length, 100);
      const sharedFields = [
        'menu_id',
        'menu_name',
        'category',
        'mood_tags',
        'situation_tags',
        'budget_min',
        'budget_max',
        'spicy_level',
        'fullness',
        'cookable',
        'eat_out',
      ];
      for (final row in oldRows) {
        final current = currentRows.singleWhere(
          (r) => r['menu_id'] == row['menu_id'],
        );
        for (final field in sharedFields) {
          expect(
            current[field],
            row[field],
            reason: '${row['menu_id']}/$field',
          );
        }
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
            final key = utf8.decode(
              message!.buffer.asUint8List(
                message.offsetInBytes,
                message.lengthInBytes,
              ),
            );
            if (key != 'assets/data/menus_dataset.json') return null;
            return ByteData.sublistView(
              Uint8List.fromList(utf8.encode(oldJson)),
            );
          });
      SharedPreferences.setMockInitialValues({});
      expect((await original.LocalRecommendService.getAllMenus()).length, 100);

      final rows = <Map<String, dynamic>>[];
      for (final mood in ['기분 좋음', '무난함', '우울함', '스트레스', '피곤함']) {
        for (final scene in ['혼밥', '친구랑', '데이트', '든든하게', '가볍게', '빨리먹기']) {
          final request = RecommendationRequest(
            mood: mood,
            situation: scene,
            budget: 25000,
          );
          for (final policy in ['desktop_original', 'current_v3']) {
            final runs = <Map<String, num>>[];
            final frequencies = <String, int>{};
            for (var repetition = 0; repetition < repetitions; repetition++) {
              SharedPreferences.setMockInitialValues({});
              final random = Random(20261013 + repetition);
              final history = <String, MenuInteractionHistory>{};
              final metrics = SequenceMetrics();
              for (var i = 0; i < drawsPerRun; i++) {
                final now = epoch.add(Duration(minutes: i));
                final MenuModel menu;
                if (policy == 'desktop_original') {
                  final picked = await original.LocalRecommendService.recommend(
                    mood: mood,
                    situation: scene,
                    budget: request.budget,
                  );
                  menu = byId[picked.menuId]!;
                } else {
                  menu = draw(
                    currentDistribution(
                      menus,
                      request,
                      RecommendationPreferences(history: history),
                      now: now,
                    ),
                    random,
                  );
                }
                metrics.add(menu, request.budget);
                final old = history[menu.menuId];
                history[menu.menuId] = MenuInteractionHistory(
                  recommendationCount: (old?.recommendationCount ?? 0) + 1,
                  lastRecommendedAt: now,
                );
              }
              runs.add(metrics.summary());
              for (final entry in metrics.counts.entries) {
                frequencies.update(
                  entry.key,
                  (value) => value + entry.value,
                  ifAbsent: () => entry.value,
                );
              }
            }
            rows.add({
              'mood': mood,
              'situation': scene,
              'policy': policy,
              'runs': runs,
              'menuFrequencies': frequencies,
              for (final metric in runs.first.keys)
                metric: mean(runs.map((r) => r[metric]!)),
            });
          }
        }
        stdout.writeln('Completed diversity: $mood');
      }

      const request = RecommendationRequest(
        mood: '스트레스',
        situation: '혼밥',
        budget: 25000,
      );
      final eligible =
          engine.rank(menus, request, now: epoch).map((e) => e.menu).toList()
            ..sort((a, b) => a.menuId.compareTo(b.menuId));
      final preferenceRows = <Map<String, dynamic>>[];
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
          'pork_over_seafood' => menu.foodTraits.mainIngredients.contains(
            '돼지고기',
          ),
          _ => menu.foodTraits.cookingMethod == '구이',
        };
        bool negative(MenuModel menu) => switch (scenario) {
          'pork_over_seafood' =>
            menu.foodTraits.mainIngredients.contains('해산물') && !positive(menu),
          'grilled_over_fried' => menu.foodTraits.cookingMethod == '튀김',
          _ => !positive(menu),
        };
        final pool = eligible.where((m) => positive(m) != negative(m)).toList();
        final train = [
          for (var i = 0; i < pool.length; i++)
            if (i % 3 != 0) pool[i],
        ].take(64).toList();
        final positiveIds = train.where(positive).map((m) => m.menuId).toSet();
        final negativeIds = train.where(negative).map((m) => m.menuId).toSet();
        final model = FeedbackLearningEngine.fit([
          for (final menu in train)
            {
              'menuId': menu.menuId,
              'features': FeedbackLearningEngine.features(menu, request),
              'liked': positive(menu),
              'disliked': negative(menu),
            },
        ]);
        expect(model.ready, isTrue);
        final measurements = <String, dynamic>{};
        for (final withFeedback in [false, true]) {
          SharedPreferences.setMockInitialValues(
            withFeedback
                ? {
                    'liked_menus_': positiveIds.toList(),
                    'disliked_menus_스트레스': negativeIds.toList(),
                  }
                : {},
          );
          final currentPreferences = withFeedback
              ? RecommendationPreferences(
                  favorites: positiveIds,
                  dislikes: negativeIds,
                  learning: model,
                )
              : const RecommendationPreferences();
          final entries = currentDistribution(
            menus,
            request,
            currentPreferences,
          );
          for (final policy in ['desktop_original', 'current_v3']) {
            final random = Random(20261013);
            var favorable = 0,
                unfavorable = 0,
                neutral = 0,
                seenDisliked = 0,
                overBudget = 0;
            final frequencies = <String, int>{};
            for (var i = 0; i < preferenceDraws; i++) {
              final menu = policy == 'desktop_original'
                  ? byId[(await original.LocalRecommendService.recommend(
                      mood: request.mood,
                      situation: request.situation,
                      budget: request.budget,
                    )).menuId]!
                  : draw(entries, random);
              if (positive(menu)) {
                favorable++;
              } else if (negative(menu)) {
                unfavorable++;
              } else {
                neutral++;
              }
              if (negativeIds.contains(menu.menuId)) seenDisliked++;
              if (menu.budgetMax > request.budget) overBudget++;
              frequencies.update(
                menu.menuId,
                (value) => value + 1,
                ifAbsent: () => 1,
              );
            }
            measurements['${policy}_${withFeedback ? 'feedback' : 'cold'}'] = {
              'drawCount': preferenceDraws,
              'favorableRate': favorable / preferenceDraws,
              'unfavorableRate': unfavorable / preferenceDraws,
              'neutralRate': neutral / preferenceDraws,
              'explicitDislikedRate': seenDisliked / preferenceDraws,
              'overBudgetRate': overBudget / preferenceDraws,
              'menuFrequencies': frequencies,
            };
          }
        }
        preferenceRows.add({
          'scenario': scenario,
          'syntheticLabels': true,
          'positiveFeedbackMenuIds': positiveIds.toList(),
          'negativeFeedbackMenuIds': negativeIds.toList(),
          'modelSampleCount': model.sampleCount,
          'measurements': measurements,
        });
        stdout.writeln('Completed preference: $scenario');
      }
      final budgetSensitivity = <Map<String, dynamic>>[];
      for (final budget in [10000, 15000, 20000, 25000, 50000]) {
        final budgetRuns = <Map<String, dynamic>>[];
        for (final mood in ['기분 좋음', '무난함', '우울함', '스트레스', '피곤함']) {
          for (final scene in ['혼밥', '친구랑', '데이트', '든든하게', '가볍게', '빨리먹기']) {
            final req = RecommendationRequest(
              mood: mood,
              situation: scene,
              budget: budget,
            );
            for (final policy in ['desktop_original', 'current_v3']) {
              for (var repetition = 0; repetition < 5; repetition++) {
                SharedPreferences.setMockInitialValues({});
                final random = Random(20261013 + repetition);
                final history = <String, MenuInteractionHistory>{};
                final metrics = SequenceMetrics();
                for (var i = 0; i < 50; i++) {
                  final now = epoch.add(Duration(minutes: i));
                  final menu = policy == 'desktop_original'
                      ? byId[(await original.LocalRecommendService.recommend(
                          mood: mood,
                          situation: scene,
                          budget: budget,
                        )).menuId]!
                      : draw(
                          currentDistribution(
                            menus,
                            req,
                            RecommendationPreferences(history: history),
                            now: now,
                          ),
                          random,
                        );
                  metrics.add(menu, budget);
                  final old = history[menu.menuId];
                  history[menu.menuId] = MenuInteractionHistory(
                    recommendationCount: (old?.recommendationCount ?? 0) + 1,
                    lastRecommendedAt: now,
                  );
                }
                budgetRuns.add({
                  'mood': mood,
                  'situation': scene,
                  'policy': policy,
                  'repetition': repetition,
                  ...metrics.summary(),
                });
              }
            }
          }
        }
        final budgetSummary = <String, dynamic>{};
        for (final policy in ['desktop_original', 'current_v3']) {
          final group = budgetRuns.where((r) => r['policy'] == policy).toList();
          budgetSummary[policy] = {
            for (final metric in [
              'uniqueMenus',
              'identicalRepeatRate',
              'similarRepeatRate',
              'overBudgetRate',
            ])
              metric: mean(group.map((r) => r[metric] as num)),
          };
        }
        budgetSensitivity.add({
          'budget': budget,
          'summary': budgetSummary,
          'runs': budgetRuns,
        });
        stdout.writeln('Completed budget sensitivity: $budget');
      }
      final summary = <String, dynamic>{};
      for (final policy in ['desktop_original', 'current_v3']) {
        final group = rows.where((r) => r['policy'] == policy).toList();
        summary[policy] = {
          for (final metric in [
            'uniqueMenus',
            'uniqueForms',
            'identicalRepeatRate',
            'similarRepeatRate',
            'overBudgetRate',
          ])
            metric: mean(group.map((r) => r[metric] as num)),
        };
      }
      final preferenceSummary = <String, dynamic>{};
      for (final policy in ['desktop_original', 'current_v3']) {
        for (final mode in ['cold', 'feedback']) {
          final key = '${policy}_$mode';
          preferenceSummary[key] = {
            for (final metric in [
              'favorableRate',
              'unfavorableRate',
              'neutralRate',
              'explicitDislikedRate',
              'overBudgetRate',
            ])
              metric: mean(
                preferenceRows.map(
                  (r) => r['measurements'][key][metric] as num,
                ),
              ),
          };
        }
      }
      final output = {
        'evaluationDate': '2026-10-13',
        'currentPolicy': 3,
        'baseline':
            'Unmodified service/model/preferences snapshots copied from desktop original',
        'datasetSharedFieldsVerified': sharedFields,
        'datasetMenuCount': menus.length,
        'diversityProtocol':
            'All 30 UI combinations; budget 25000; any spiciness; 20 runs of 100 independent recommendations each; fresh preferences per run; current history advances one minute per draw; no session exclusions',
        'randomness':
            'Original List.shuffle() has no injected seed; original measurements vary between runs. Current uses seeds 20261013..20261032. Raw frequencies and per-run statistics are saved.',
        'preferenceProtocol':
            'Five synthetic rules; max 64 training menus; same like/dislike training IDs given to both algorithms; original favorites saved in mock SharedPreferences; current direct preferences plus learned model; sample whole 100-menu catalog 2000 times per scenario/policy/mode; no history update in this experiment. NOT held-out recommendation accuracy.',
        'limitations':
            'Local execution with mocked asset bundle and preferences, no real users/server. One dataset/budget/time interval. Current uses explicit traits also to score diversity. Synthetic preference figures are sampled menu proportions, not user satisfaction.',
        'totalDraws':
            30 * repetitions * drawsPerRun * 2 +
            5 * preferenceDraws * 4 +
            5 * 30 * 5 * 50 * 2,
        'diversitySummary': summary,
        'preferenceSummary': preferenceSummary,
        'diversityScenarios': rows,
        'preferenceScenarios': preferenceRows,
        'budgetSensitivityProtocol':
            'Five budgets; each all 30 UI combinations; five runs of 50 recommendations per policy; cold start with one-minute exposure updates; independent from the 100-draw main experiment',
        'budgetSensitivity': budgetSensitivity,
      };
      final file = File(
        'docs/evaluations/original-recommendation-comparison.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(output)}\n',
      );
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert({
          'diversitySummary': summary,
          'preferenceSummary': preferenceSummary,
          'totalDraws': output['totalDraws'],
        }),
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: const bool.fromEnvironment('RUN_ORIGINAL_BENCHMARK')
        ? false
        : 'Run explicitly with --dart-define=RUN_ORIGINAL_BENCHMARK=true',
  );
}
