import 'dart:async';
import 'dart:convert';
import 'preference_store.dart';
import '../models/recommendation_model.dart';
import '../models/learning_model.dart';
import 'feedback_learning_engine.dart';
import 'learning_feedback_recorder.dart';
import 'menu_catalog_service.dart';

/// Account-scoped storage. Legacy keys remain untouched because their
/// owner cannot be established safely. Writes are serialized to avoid lost taps.
class UserMenuPreferenceService {
  static PreferenceStore store = LocalPreferenceStore();
  static String Function() scopeProvider = () => 'demo';
  static DateTime Function() clock = () => DateTime.now().toUtc();
  static Future<void> _pending = Future.value();

  static Future<void> _write(
    Future<void> Function(PreferenceData) action, {
    bool migrateLearning = true,
  }) {
    final scope = scopeProvider();
    final capturedStore = store;
    final operation = _pending.then((_) async {
      final catalog = await MenuCatalogService.byId();
      return capturedStore.update(scope, (data) async {
        final raw = data.values['learning'];
        if (migrateLearning && raw is Map && raw['version'] == 1) {
          data.values['learning'] = FeedbackLearningEngine.state(
            FeedbackLearningEngine.events(raw, clock(), catalog: catalog),
          );
        }
        await action(data);
      });
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  static Future<List<String>> _list(String suffix) async {
    final scope = scopeProvider();
    final capturedStore = store;
    await _pending;
    final prefs = await capturedStore.read(scope);
    return List.of(prefs.getStringList(suffix) ?? []);
  }

  static Future<void> _change(String suffix, String id, bool add) =>
      _write((prefs) async {
        final key = suffix;
        final values = (prefs.getStringList(key) ?? []).toSet();
        add ? values.add(id) : values.remove(id);
        if (!await prefs.setStringList(key, values.toList())) {
          throw StateError('저장에 실패했습니다.');
        }
        if (suffix == 'favorites' && !add) {
          LearningFeedbackRecorder.retractLikes(prefs, id, clock());
        }
      });

  static Future<void> _clear(List<String> suffixes) => _write((prefs) async {
    for (final suffix in suffixes) {
      if (!await prefs.remove(suffix)) {
        throw StateError('초기화에 실패했습니다.');
      }
    }
    for (final suffix in suffixes.where((key) => key.startsWith('disliked_'))) {
      LearningFeedbackRecorder.resetMood(prefs, suffix.substring(9), clock());
    }
    if (suffixes.contains('favorites')) {
      LearningFeedbackRecorder.retractLikes(prefs, null, clock());
    }
  });

  static Future<void> dislikeMenuForMood({
    required String mood,
    required String menuId,
  }) => _change('disliked_$mood', menuId, true);
  static Future<List<String>> getDislikedMenuIdsForMood(String mood) =>
      _list('disliked_$mood');
  static Future<void> clearDislikedMenusForMood(String mood) =>
      _clear(['disliked_$mood']);
  static Future<void> likeMenu({required String menuId}) =>
      addFavoriteMenu(menuId);
  static Future<List<String>> getFavoriteMenuIds() => _list('favorites');
  static Future<void> addFavoriteMenu(String menuId) =>
      _change('favorites', menuId, true);
  static Future<void> removeFavoriteMenu(String menuId) =>
      _change('favorites', menuId, false);
  static Future<bool> isFavoriteMenu(String menuId) async =>
      (await getFavoriteMenuIds()).contains(menuId);
  static Future<void> clearFavoriteMenus() => _clear(['favorites']);

  static Future<void> _setMood(String menuId, String mood, bool add) => _write((
    prefs,
  ) async {
    final addedKey = 'added_$mood';
    final removedKey = 'removed_$mood';
    final added = (prefs.getStringList(addedKey) ?? []).toSet();
    final removed = (prefs.getStringList(removedKey) ?? []).toSet();
    if (add) {
      added.add(menuId);
      removed.remove(menuId);
    } else {
      removed.add(menuId);
      added.remove(menuId);
    }
    if (!await prefs.setStringList(addedKey, added.toList()) ||
        !await prefs.setStringList(removedKey, removed.toList())) {
      throw StateError('저장에 실패했습니다.');
    }
    // Explicit re-addition restores a previously rejected menu in this mood.
    if (add) {
      final dislikeKey = 'disliked_$mood';
      final dislikes = (prefs.getStringList(dislikeKey) ?? []).toSet();
      dislikes.remove(menuId);
      if (!await prefs.setStringList(dislikeKey, dislikes.toList())) {
        throw StateError('저장에 실패했습니다.');
      }
      LearningFeedbackRecorder.restoreMenu(prefs, menuId, mood, clock());
    }
  });

  static Future<void> addMoodForMenu({
    required String menuId,
    required String mood,
  }) => _setMood(menuId, mood, true);
  static Future<void> removeMoodForMenu({
    required String menuId,
    required String mood,
  }) => _setMood(menuId, mood, false);
  static Future<List<String>> getAddedMoodMenuIds(String mood) =>
      _list('added_$mood');
  static Future<List<String>> getRemovedMoodMenuIds(String mood) =>
      _list('removed_$mood');
  static Future<bool> isMenuAddedToMood({
    required String menuId,
    required String mood,
  }) async => (await getAddedMoodMenuIds(mood)).contains(menuId);
  static Future<bool> isMenuRemovedFromMood({
    required String menuId,
    required String mood,
  }) async => (await getRemovedMoodMenuIds(mood)).contains(menuId);
  static Future<void> clearMoodCustomizations(String mood) =>
      _clear(['added_$mood', 'removed_$mood', 'disliked_$mood']);

  static Map<String, int> _counts(PreferenceData prefs) {
    final raw = prefs.getString('selections');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is int && entry.value >= 0)
            entry.key: entry.value as int,
      };
    } on FormatException {
      return {};
    }
  }

  static Map<String, MenuInteractionHistory> _history(PreferenceData prefs) {
    final raw = prefs.getString('interaction_history');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: MenuInteractionHistory.fromMap(
              entry.value as Map<String, dynamic>,
            ),
      };
    } on FormatException {
      return {};
    }
  }

  static Future<void> _record(String menuId, {required bool selection}) {
    final occurredAt = clock().toUtc();
    return _write((prefs) async {
      final history = _history(prefs);
      // Upgrade this account's old counts lazily, without inventing dates.
      for (final entry in _counts(prefs).entries) {
        history.putIfAbsent(
          entry.key,
          () => MenuInteractionHistory(selectionCount: entry.value),
        );
      }
      final previous = history[menuId] ?? const MenuInteractionHistory();
      history[menuId] = MenuInteractionHistory(
        recommendationCount: previous.recommendationCount + (selection ? 0 : 1),
        selectionCount: previous.selectionCount + (selection ? 1 : 0),
        lastRecommendedAt: selection ? previous.lastRecommendedAt : occurredAt,
        lastSelectedAt: selection ? occurredAt : previous.lastSelectedAt,
        lastExposureId: previous.lastExposureId,
      );
      // Count and date share one value so interrupted writes cannot split them.
      if (!await prefs.setString(
        'interaction_history',
        jsonEncode(history.map((id, value) => MapEntry(id, value.toMap()))),
      )) {
        throw StateError('저장에 실패했습니다.');
      }
    });
  }

  static Future<void> recordSelection(String menuId) =>
      _record(menuId, selection: true);

  static Future<void> recordRecommendation(String menuId) =>
      _record(menuId, selection: false);

  static Future<void> recordExposure(RecommendationExposure exposure) =>
      recommendationFeedback(exposure, null);

  static Future<void> recommendationFeedback(
    RecommendationExposure exposure,
    RecommendationFeedback? feedback,
  ) {
    if (exposure.scope != scopeProvider()) {
      return Future.error(StateError('로그인 상태가 변경됐어요. 메뉴를 다시 추천받아 주세요.'));
    }
    final now = clock();
    return _write(
      (prefs) => LearningFeedbackRecorder.apply(prefs, exposure, feedback, now),
    );
  }

  static Future<void> resetLearning() => _write((prefs) async {
    prefs.values['learning'] = FeedbackLearningEngine.state([]);
  }, migrateLearning: false);

  static Future<RecommendationPreferences> snapshot(String mood) async {
    final scope = scopeProvider();
    final capturedStore = store;
    await _pending;
    final prefs = await capturedStore.read(scope);
    final catalog = await MenuCatalogService.byId();
    Set<String> values(String suffix) =>
        Set.unmodifiable(prefs.getStringList(suffix) ?? []);
    final history = _history(prefs);
    final counts = _counts(prefs);
    for (final entry in history.entries) {
      counts[entry.key] = entry.value.selectionCount;
    }
    return RecommendationPreferences(
      favorites: values('favorites'),
      dislikes: values('disliked_$mood'),
      added: values('added_$mood'),
      removed: values('removed_$mood'),
      selections: Map.unmodifiable(counts),
      history: Map.unmodifiable(history),
      learning: prefs.values['learning'] == null
          ? const LearningProfile()
          : FeedbackLearningEngine.fit(
              FeedbackLearningEngine.events(
                prefs.values['learning'],
                clock(),
                catalog: catalog,
              ),
            ),
    );
  }
}
