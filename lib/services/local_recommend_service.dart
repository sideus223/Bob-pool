import 'dart:math';
import 'menu_catalog_service.dart';
import '../models/menu_model.dart';
import '../models/recommendation_model.dart';
import 'recommendation_engine.dart';
import 'softmax_sampler.dart';
import 'user_menu_preference_service.dart';
import '../models/learning_model.dart';
import 'feedback_learning_engine.dart';
import '../core/app_config.dart';

class LocalRecommendService {
  static Future<List<MenuModel>> getAllMenus() => MenuCatalogService.getAll();

  static Future<List<RankedMenu>> rank(
    RecommendationRequest request, {
    Set<String> excludedIds = const {},
  }) async {
    final scope = UserMenuPreferenceService.scopeProvider();
    final preferences = await UserMenuPreferenceService.snapshot(request.mood);
    final menus = await getAllMenus();
    if (scope != UserMenuPreferenceService.scopeProvider()) {
      throw StateError('로그인 상태가 변경됐어요. 다시 추천받아 주세요.');
    }
    return RecommendationEngine()
        .rank(
          menus,
          request,
          preferences: preferences,
          excludedIds: excludedIds,
          now: UserMenuPreferenceService.clock(),
          learningEnabled: AppConfig.learningEnabled,
        )
        .map(
          (result) => RankedMenu(
            result.menu,
            result.contributions,
            result.reasons,
            accountScope: scope,
            learnedModelActive: result.learnedModelActive,
            explorationEligible: result.explorationEligible,
            exposureCount: result.exposureCount,
          ),
        )
        .toList(growable: false);
  }

  static Future<MenuModel> recommend({
    required String mood,
    required String situation,
    required int budget,
    String selectedSpicy = '상관없음',
    String? excludeMenuId,
  }) async {
    final ranked = await rank(
      RecommendationRequest(
        mood: mood,
        situation: situation,
        budget: budget,
        spicy: selectedSpicy,
      ),
      excludedIds: {?excludeMenuId},
    );
    if (ranked.isEmpty) {
      throw const NoRecommendationException(
        '조건에 맞는 다른 메뉴가 없어요. 예산이나 맵기를 직접 변경해 주세요.',
      );
    }
    return pick(ranked).menu;
  }

  /// Use the full eligible pool; low-scored menus keep a small chance.
  static RankedMenu pick(List<RankedMenu> candidates, {Random? random}) =>
      SoftmaxSampler().draw(
        candidates,
        random: random,
        explorationRate: SoftmaxSampler.defaultExplorationRate,
      );

  static ({RankedMenu result, RecommendationExposure exposure})
  pickWithExposure(
    List<RankedMenu> candidates,
    RecommendationRequest request, {
    Random? random,
  }) {
    final result = pick(candidates, random: random);
    final scope =
        result.accountScope ?? UserMenuPreferenceService.scopeProvider();
    if (scope != UserMenuPreferenceService.scopeProvider()) {
      throw StateError('로그인 상태가 변경됐어요. 다시 추천받아 주세요.');
    }
    final probability = SoftmaxSampler()
        .distribution(
          candidates,
          explorationRate: SoftmaxSampler.defaultExplorationRate,
        )
        .firstWhere((item) => item.candidate.menu.menuId == result.menu.menuId)
        .probability;
    final secure = Random.secure();
    final id = List.generate(
      16,
      (_) => secure.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return (
      result: result,
      exposure: RecommendationExposure(
        id: id,
        scope: scope,
        menuId: result.menu.menuId,
        mood: request.mood,
        situation: request.situation,
        budget: request.budget,
        spicy: request.spicy,
        features: FeedbackLearningEngine.features(result.menu, request),
        candidateIds: candidates.map((c) => c.menu.menuId).toList(),
        drawProbability: probability,
        score: result.score,
        learned: result.learnedModelActive,
        createdAt: UserMenuPreferenceService.clock().millisecondsSinceEpoch,
        policyVersion: 3,
      ),
    );
  }

  static Future<MenuModel> recommendRandom({String? excludeMenuId}) async {
    final pool = (await getAllMenus())
        .where((m) => m.menuId != excludeMenuId)
        .toList();
    if (pool.isEmpty) throw const NoRecommendationException('다른 메뉴가 없습니다.');
    return pool[Random().nextInt(pool.length)];
  }
}
