import '../models/learning_model.dart';
import '../models/recommendation_model.dart';
import 'feedback_learning_engine.dart';
import 'preference_store.dart';

/// Runs inside the same transaction as the preference and history changes.
class LearningFeedbackRecorder {
  static Future<void> apply(
    PreferenceData data,
    RecommendationExposure exposure,
    RecommendationFeedback? feedback,
    DateTime now,
  ) async {
    if (!FeedbackLearningEngine.validEvent(exposure.toMap())) {
      throw StateError('추천 기록의 형식이 올바르지 않아요.');
    }
    final age = now.millisecondsSinceEpoch - exposure.createdAt;
    if (age < 0 || age > FeedbackLearningEngine.retention.inMilliseconds) {
      throw StateError('추천 기록이 만료됐어요. 메뉴를 다시 추천받아 주세요.');
    }
    final events = FeedbackLearningEngine.events(data.values['learning'], now);
    var index = events.indexWhere((event) => event['id'] == exposure.id);
    final isNew = index < 0;
    if (isNew) {
      final history = data.values['interaction_history'];
      final raw = history is Map ? history[exposure.menuId] : null;
      if (raw is Map) {
        final previous = MenuInteractionHistory.fromMap(
          Map<String, dynamic>.from(raw),
        );
        final lastAt = previous.lastRecommendedAt?.millisecondsSinceEpoch;
        if (previous.lastExposureId == exposure.id ||
            (lastAt != null &&
                lastAt <= now.millisecondsSinceEpoch &&
                exposure.createdAt < lastAt)) {
          throw StateError('오래된 추천 기록이에요. 메뉴를 다시 추천받아 주세요.');
        }
      }
      if (events.length == FeedbackLearningEngine.retainedEvents &&
          exposure.createdAt <= (events.first['createdAt'] as int)) {
        throw StateError('오래된 추천 기록이에요. 메뉴를 다시 추천받아 주세요.');
      }
      events.add(exposure.toMap());
      index = events.length - 1;
    } else if (events[index]['menuId'] != exposure.menuId) {
      throw StateError('추천 기록이 일치하지 않아요.');
    }
    final event = events[index];
    final wasSelected = event['selected'] == true;
    if (feedback != null) {
      switch (feedback) {
        case RecommendationFeedback.like:
          event['liked'] = true;
        case RecommendationFeedback.unlike:
          event['liked'] = false;
        case RecommendationFeedback.select:
          event['selected'] = true;
        case RecommendationFeedback.dislike:
          event['disliked'] = true;
      }
      event['feedbackAt'] = now.millisecondsSinceEpoch;
    }
    final selection = !wasSelected && event['selected'] == true;
    if (isNew || selection) {
      Map<String, dynamic> decode(String key) {
        final value = data.values[key];
        return value is Map ? Map<String, dynamic>.from(value) : {};
      }

      final history = decode('interaction_history');
      for (final entry in decode('selections').entries) {
        history.putIfAbsent(entry.key, () => {'selectionCount': entry.value});
      }
      final raw = history[exposure.menuId];
      final previous = raw is Map
          ? MenuInteractionHistory.fromMap(Map<String, dynamic>.from(raw))
          : const MenuInteractionHistory();
      history[exposure.menuId] = MenuInteractionHistory(
        recommendationCount: previous.recommendationCount + (isNew ? 1 : 0),
        selectionCount: previous.selectionCount + (selection ? 1 : 0),
        lastRecommendedAt: isNew
            ? DateTime.fromMillisecondsSinceEpoch(
                exposure.createdAt,
                isUtc: true,
              )
            : previous.lastRecommendedAt,
        lastSelectedAt: selection ? now : previous.lastSelectedAt,
        lastExposureId: isNew ? exposure.id : previous.lastExposureId,
      ).toMap();
      data.values['interaction_history'] = history;
    }
    if (feedback == RecommendationFeedback.like ||
        feedback == RecommendationFeedback.unlike) {
      final favorites = (data.getStringList('favorites') ?? []).toSet();
      feedback == RecommendationFeedback.like
          ? favorites.add(exposure.menuId)
          : favorites.remove(exposure.menuId);
      await data.setStringList('favorites', favorites.toList());
    }
    if (feedback == RecommendationFeedback.dislike) {
      final key = 'disliked_${exposure.mood}';
      final disliked = (data.getStringList(key) ?? []).toSet()
        ..add(exposure.menuId);
      await data.setStringList(key, disliked.toList());
    }
    final retained = FeedbackLearningEngine.retainEvents(events);
    if (!retained.any((item) => item['id'] == exposure.id)) {
      throw StateError('오래된 추천 기록이에요. 메뉴를 다시 추천받아 주세요.');
    }
    data.values['learning'] = FeedbackLearningEngine.state(retained);
  }

  static void resetMood(PreferenceData data, String mood, DateTime now) {
    if (!data.values.containsKey('learning')) return;
    final events = FeedbackLearningEngine.events(data.values['learning'], now)
        .where(
          (event) =>
              (event['mood'] as String).replaceAll(' ', '') !=
              mood.replaceAll(' ', ''),
        )
        .toList();
    data.values['learning'] = FeedbackLearningEngine.state(events);
  }

  static void retractLikes(PreferenceData data, String? menuId, DateTime now) {
    if (!data.values.containsKey('learning')) return;
    final events = FeedbackLearningEngine.events(data.values['learning'], now);
    for (final event in events) {
      if (menuId == null || event['menuId'] == menuId) event['liked'] = false;
    }
    data.values['learning'] = FeedbackLearningEngine.state(events);
  }

  static void restoreMenu(
    PreferenceData data,
    String menuId,
    String mood,
    DateTime now,
  ) {
    if (!data.values.containsKey('learning')) return;
    final events = FeedbackLearningEngine.events(data.values['learning'], now)
        .where(
          (event) =>
              !(event['menuId'] == menuId &&
                  event['disliked'] == true &&
                  (event['mood'] as String).replaceAll(' ', '') ==
                      mood.replaceAll(' ', '')),
        )
        .toList();
    data.values['learning'] = FeedbackLearningEngine.state(events);
  }
}
