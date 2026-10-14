import '../models/menu_model.dart';
import '../models/recommendation_model.dart';
import 'feedback_learning_engine.dart';
import 'recommendation_diversity.dart';

/// Pure Dart hybrid ranking: mandatory filters, fixed rules and learned bonus.
class RecommendationEngine {
  static const moodWeight = 30;
  static const situationWeight = 25;
  static const favoriteWeight = 20;
  static const customMoodWeight = 15;
  static const selectionWeight = 5;
  static const maxSelectionCount = 3;
  static const dislikeWeight = -60;
  static const recentRecommendationWeight = -20;
  static const recentSelectionWeight = -50;
  static const weekSelectionWeight = -20;

  List<RankedMenu> rank(
    List<MenuModel> menus,
    RecommendationRequest request, {
    RecommendationPreferences preferences = const RecommendationPreferences(),
    Set<String> excludedIds = const {},
    bool learningEnabled = true,
    DateTime? now,
  }) {
    final evaluatedAt = now ?? DateTime.now().toUtc();
    if (request.budget <= 0) {
      throw const NoRecommendationException('예산은 0원보다 커야 합니다.');
    }
    final mood = request.mood.replaceAll(' ', '');
    final learnedConfidence = learningEnabled
        ? preferences.learning.mixedConfidence
        : 0.0;
    // Generic tag matches are a starting prior, not a permanent veto over a
    // user's reactions. Explicit favorites, custom additions and dislikes
    // retain their weights as mixed feedback grows.
    final tagScale = 1 - 0.6 * learnedConfidence;
    final previous = RecommendationDiversity.lastMenu(
      menus,
      preferences.history,
      evaluatedAt,
    );
    final results = <RankedMenu>[];
    for (final menu in menus) {
      // The upper price estimate must fit within the user's ceiling.
      if (menu.budgetMin <= 0 ||
          menu.budgetMax < menu.budgetMin ||
          menu.budgetMax > request.budget ||
          excludedIds.contains(menu.menuId) ||
          preferences.removed.contains(menu.menuId)) {
        continue;
      }
      if (request.spicy != '상관없음' && request.spicy != menu.spicyLevel) continue;
      final id = menu.menuId;
      final parts = <String, int>{};
      final reasons = <String>['예상 가격 상한이 최대 예산 이내예요'];
      if (request.spicy != '상관없음') reasons.add('선택한 맵기와 같아요');
      final added = preferences.added.contains(id);
      if (added ||
          menu.moodTags.any((tag) => tag.replaceAll(' ', '') == mood)) {
        parts['mood'] = added ? moodWeight : (moodWeight * tagScale).round();
        reasons.add('${request.mood} 기분에 연결된 메뉴예요');
      }
      if (menu.situationTags.contains(request.situation)) {
        parts['situation'] = (situationWeight * tagScale).round();
        reasons.add('${request.situation} 상황에 어울려요');
      }
      if (preferences.favorites.contains(id)) {
        parts['favorite'] = favoriteWeight;
        reasons.add('찜한 메뉴를 우선 반영했어요');
      }
      if (added) {
        parts['customMood'] = customMoodWeight;
        reasons.add('이 기분에 직접 추가한 메뉴예요');
      }
      final count = (preferences.selections[id] ?? 0).clamp(
        0,
        maxSelectionCount,
      );
      if (count > 0) {
        parts['selection'] = count * selectionWeight;
        reasons.add('이전에 선택한 메뉴예요');
      }
      if (preferences.dislikes.contains(id)) {
        parts['dislike'] = dislikeWeight;
        reasons.add('이 기분에서 별로예요라고 한 메뉴라 우선순위를 크게 낮췄어요');
      }
      final history = preferences.history[id];
      final similar = RecommendationDiversity.similar(menu, previous);
      if (similar) {
        parts['similarRecentMenu'] = RecommendationDiversity.weight;
        reasons.add('최근 추천과 비슷한 종류라 다른 음식을 먼저 살펴보도록 점수를 조정했어요');
      }
      final recommendedAge = _age(history?.lastRecommendedAt, evaluatedAt);
      if (recommendedAge != null &&
          recommendedAge < const Duration(hours: 24)) {
        parts['recentRecommendation'] = recentRecommendationWeight;
        reasons.add('최근 추천한 메뉴라 반복을 줄이도록 우선순위를 낮췄어요');
      }
      final selectedAge = _age(history?.lastSelectedAt, evaluatedAt);
      if (selectedAge != null && selectedAge < const Duration(days: 7)) {
        parts['recentSelection'] = selectedAge < const Duration(hours: 48)
            ? recentSelectionWeight
            : weekSelectionWeight;
        reasons.add('최근 선택한 메뉴라 다른 한 끼를 먼저 살펴볼 수 있게 했어요');
      }
      final learned = learningEnabled
          ? FeedbackLearningEngine.adjustment(
              preferences.learning,
              FeedbackLearningEngine.features(menu, request),
            )
          : 0;
      if (learned != 0) {
        parts['learnedPreference'] = learned;
        reasons.add(
          learned > 0
              ? '이전 반응에서 학습한 메뉴 특성을 반영했어요'
              : '이전 반응에서 학습한 선호에 따라 우선순위를 낮췄어요',
        );
      }
      results.add(
        RankedMenu(
          menu,
          parts,
          reasons,
          learnedModelActive: learningEnabled && preferences.learning.ready,
          exposureCount: history?.recommendationCount ?? 0,
          explorationEligible:
              !preferences.dislikes.contains(id) &&
              !similar &&
              learned >= 0 &&
              (recommendedAge == null ||
                  recommendedAge >= const Duration(hours: 24)) &&
              (selectedAge == null || selectedAge >= const Duration(days: 7)),
        ),
      );
    }
    // Rotate equal scores toward unseen/older/less exposed menus. The same
    // preferences and evaluation time still produce a reproducible ranking.
    results.sort((a, b) {
      final order = b.score.compareTo(a.score);
      if (order != 0) return order;
      final aHistory = preferences.history[a.menu.menuId];
      final bHistory = preferences.history[b.menu.menuId];
      final aTime = _validTime(aHistory?.lastRecommendedAt, evaluatedAt);
      final bTime = _validTime(bHistory?.lastRecommendedAt, evaluatedAt);
      if (aTime == null && bTime != null) return -1;
      if (aTime != null && bTime == null) return 1;
      if (aTime != null && bTime != null) {
        final oldest = aTime.compareTo(bTime);
        if (oldest != 0) return oldest;
      }
      final exposure = (aHistory?.recommendationCount ?? 0).compareTo(
        bHistory?.recommendationCount ?? 0,
      );
      return exposure != 0 ? exposure : a.menu.menuId.compareTo(b.menu.menuId);
    });
    return List.unmodifiable(results);
  }

  // Future timestamps can result from device clock changes. Ignore them rather
  // than applying a penalty indefinitely.
  DateTime? _validTime(DateTime? time, DateTime now) =>
      time == null || time.isAfter(now) ? null : time;

  Duration? _age(DateTime? time, DateTime now) {
    final valid = _validTime(time, now);
    return valid == null ? null : now.difference(valid);
  }
}
