import 'menu_model.dart';
import 'learning_model.dart';

class RecommendationRequest {
  final String mood;
  final String situation;
  final int budget;
  final String spicy;
  const RecommendationRequest({
    required this.mood,
    required this.situation,
    required this.budget,
    this.spicy = '상관없음',
  });
}

/// One immutable preference snapshot per ranking, scoped to a single account.
class RecommendationPreferences {
  final Set<String> favorites;
  final Set<String> dislikes;
  final Set<String> added;
  final Set<String> removed;
  final Map<String, int> selections;
  final Map<String, MenuInteractionHistory> history;
  final LearningProfile learning;
  const RecommendationPreferences({
    this.favorites = const {},
    this.dislikes = const {},
    this.added = const {},
    this.removed = const {},
    this.selections = const {},
    this.history = const {},
    this.learning = const LearningProfile(),
  });
}

/// Exposure is separate from a user's explicit choice; neither implies eating.
class MenuInteractionHistory {
  final int recommendationCount;
  final int selectionCount;
  final DateTime? lastRecommendedAt;
  final DateTime? lastSelectedAt;
  final String? lastExposureId;

  const MenuInteractionHistory({
    this.recommendationCount = 0,
    this.selectionCount = 0,
    this.lastRecommendedAt,
    this.lastSelectedAt,
    this.lastExposureId,
  });

  Map<String, Object?> toMap() => {
    'recommendationCount': recommendationCount,
    'selectionCount': selectionCount,
    'lastRecommendedAt': lastRecommendedAt?.toUtc().millisecondsSinceEpoch,
    'lastSelectedAt': lastSelectedAt?.toUtc().millisecondsSinceEpoch,
    if (lastExposureId != null) 'lastExposureId': lastExposureId,
  };

  factory MenuInteractionHistory.fromMap(Map<String, dynamic> data) {
    int count(String key) {
      final value = data[key];
      return value is int && value >= 0 ? value : 0;
    }

    DateTime? date(String key) {
      final value = data[key];
      if (value is! int || value < 0 || value > 8640000000000000) return null;
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    return MenuInteractionHistory(
      recommendationCount: count('recommendationCount'),
      selectionCount: count('selectionCount'),
      lastRecommendedAt: date('lastRecommendedAt'),
      lastSelectedAt: date('lastSelectedAt'),
      lastExposureId: data['lastExposureId'] is String
          ? data['lastExposureId'] as String
          : null,
    );
  }
}

class RankedMenu {
  final MenuModel menu;
  final Map<String, int> contributions;
  final List<String> reasons;
  final String? accountScope;
  final bool learnedModelActive;
  final bool explorationEligible;
  final int exposureCount;
  RankedMenu(
    this.menu,
    Map<String, int> contributions,
    List<String> reasons, {
    this.accountScope,
    this.learnedModelActive = false,
    this.explorationEligible = false,
    this.exposureCount = 0,
  }) : contributions = Map.unmodifiable(contributions),
       reasons = List.unmodifiable(reasons);
  int get score => contributions.values.fold(0, (sum, value) => sum + value);
}

/// Algorithmic draw probability, not confidence that the user likes this menu.
class MenuProbability {
  final RankedMenu candidate;
  final double probability;
  const MenuProbability(this.candidate, this.probability);
}

class NoRecommendationException implements Exception {
  final String message;
  const NoRecommendationException(this.message);
  @override
  String toString() => message;
}
