import 'dart:math';
import '../models/learning_feature_schema.dart';
import '../models/learning_model.dart';
import '../models/menu_model.dart';
import '../models/recommendation_model.dart';

/// Small content-based logistic regression, fitted by deterministic SGD.
/// Refit the bounded feedback window so a retracted like can be unlearned.
class FeedbackLearningEngine {
  static const retainedEvents = 64;
  static const retention = Duration(days: 30);
  static const pendingReserve = 16;
  static const maxMixedAdjustment = 30;
  static const maxOneSidedAdjustment = 6;

  static List<double> features(MenuModel menu, RecommendationRequest request) {
    final vector = List<double>.filled(LearningProfile.dimension, 0);
    void add(String key, [double value = 1]) {
      final index = LearningFeatureSchema.index[key];
      if (index != null) vector[index] = value;
    }

    final mood = request.mood.replaceAll(' ', '');
    add('category:${menu.category}');
    add('spice:${menu.spicyLevel}');
    add('fullness:${menu.fullness}');
    if (menu.cookable) add('cookable');
    if (menu.eatOut) add('eatOut');
    add('price', (menu.budgetMax / max(1, request.budget)).clamp(0, 1));
    final traits = menu.foodTraits;
    for (final ingredient in traits.mainIngredients) {
      add('ingredient:$ingredient');
    }
    add('method:${traits.cookingMethod}');
    add('form:${traits.foodForm}');
    for (final taste in traits.tasteTags) {
      add('taste:$taste');
    }
    add('mood:$mood/form:${traits.foodForm}');
    add('scene:${request.situation}/form:${traits.foodForm}');
    final norm = sqrt(vector.fold(0.0, (sum, x) => sum + x * x));
    return List.unmodifiable(vector.map((x) => norm == 0 ? 0.0 : x / norm));
  }

  static bool validFeatures(
    Object? raw, {
    int dimension = LearningProfile.dimension,
  }) =>
      raw is List &&
      raw.length == dimension &&
      raw.every((v) => v is num && v.isFinite && v.abs() <= 1) &&
      raw.fold<double>(0, (sum, v) => sum + (v as num) * v) <= 1.000001;

  static double predict(List<double> weights, List<double> features) {
    if (!validFeatures(features)) throw ArgumentError('Invalid features');
    if (weights.isEmpty) return 0.5;
    if (weights.length != LearningProfile.dimension ||
        weights.any((v) => !v.isFinite || v.abs() > 4)) {
      throw ArgumentError('Invalid model weights');
    }
    final dot = List.generate(
      weights.length,
      (i) => weights[i] * features[i],
    ).fold(0.0, (sum, v) => sum + v).clamp(-20.0, 20.0);
    return 1 / (1 + exp(-dot));
  }

  static int adjustment(LearningProfile profile, List<double> features) {
    if (!profile.ready) return 0;
    final centered = (predict(profile.weights, features) - 0.5) * 2;
    if (!profile.hasStrongFeedback) {
      final supported = profile.hasMixedFeedback
          ? centered
          : profile.positives > 0
          ? centered.clamp(0.0, 1.0)
          : centered.clamp(-1.0, 0.0);
      return (supported *
              maxOneSidedAdjustment *
              (profile.sampleCount / 8).clamp(0.0, 1.0))
          .round()
          .clamp(-maxOneSidedAdjustment, maxOneSidedAdjustment);
    }
    return (centered * maxMixedAdjustment * profile.mixedConfidence)
        .round()
        .clamp(-maxMixedAdjustment, maxMixedAdjustment);
  }

  static int? label(Map<String, dynamic> event) {
    if (event['disliked'] == true) return 0;
    if (event['selected'] == true || event['liked'] == true) return 1;
    return null; // No response, refresh and unlike are not negative labels.
  }

  static bool validEvent(Object? item, {bool legacy = false}) {
    if (item is! Map) return false;
    bool text(Object? value, int maxLength) =>
        value is String && value.isNotEmpty && value.length <= maxLength;
    final ids = item['candidateIds'];
    final probability = item['drawProbability'];
    final created = item['createdAt'];
    final feedback = item['feedbackAt'];
    return text(item['id'], 64) &&
        text(item['menuId'], 40) &&
        text(item['mood'], 20) &&
        text(item['situation'], 20) &&
        item['budget'] is int &&
        item['budget'] > 0 &&
        ['상관없음', '순함', '보통', '매움'].contains(item['spicy']) &&
        validFeatures(
          item['features'],
          dimension: legacy ? 64 : LearningProfile.dimension,
        ) &&
        (legacy
            ? item['featureVersion'] == null || item['featureVersion'] == 1
            : item['featureVersion'] == null ||
                  item['featureVersion'] == LearningProfile.version) &&
        ids is List &&
        ids.isNotEmpty &&
        ids.length <= 100 &&
        ids.every((id) => text(id, 40)) &&
        ids.toSet().length == ids.length &&
        ids.contains(item['menuId']) &&
        probability is num &&
        probability.isFinite &&
        probability > 0 &&
        probability <= 1 &&
        item['score'] is int &&
        ['rules-v2', 'hybrid-v1'].contains(item['policy']) &&
        (!item.containsKey('policyVersion') ||
            (item['policyVersion'] is int &&
                [1, 2, 3].contains(item['policyVersion']))) &&
        created is int &&
        created >= 0 &&
        created <= 8640000000000000 &&
        (feedback == null ||
            feedback is int && feedback >= 0 && feedback <= 8640000000000000) &&
        item['liked'] is bool &&
        item['selected'] is bool &&
        item['disliked'] is bool;
  }

  static LearningProfile fit(List<Map<String, dynamic>> events) {
    final samples = events
        .where((e) => label(e) != null && validFeatures(e['features']))
        .toList();
    if (samples.length > retainedEvents) {
      throw ArgumentError('Too many samples');
    }
    final positives = samples.where((e) => label(e) == 1).length;
    final negatives = samples.length - positives;
    // A majority of dislikes should not drown the few explicit likes. Bound
    // the correction so one rare reaction cannot receive unbounded influence.
    double classWeight(int target) => positives == 0 || negatives == 0
        ? 1.0
        : (samples.length / (2 * (target == 1 ? positives : negatives))).clamp(
            0.0,
            4.0,
          );
    final weights = List<double>.filled(LearningProfile.dimension, 0);
    for (var epoch = 0; epoch < 24; epoch++) {
      final rate = 0.4 / sqrt(epoch + 1);
      for (final sample in samples) {
        final x = (sample['features'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        final target = label(sample)!;
        final error = (target - predict(weights, x)) * classWeight(target);
        for (var i = 0; i < weights.length; i++) {
          weights[i] = (weights[i] + rate * (error * x[i] - 0.01 * weights[i]))
              .clamp(-4.0, 4.0);
        }
      }
    }
    return LearningProfile(
      weights: List.unmodifiable(weights),
      sampleCount: samples.length,
      positives: positives,
      negatives: samples.length - positives,
      distinctMenus: samples.map((e) => e['menuId']).toSet().length,
    );
  }

  static List<Map<String, dynamic>> events(
    Object? state,
    DateTime now, {
    Map<String, MenuModel>? catalog,
  }) {
    if (state == null) return [];
    final profile = LearningProfile.fromMap(
      state,
    ); // Unknown versions are never overwritten.
    final legacy = profile.modelVersion == 1;
    if (legacy && catalog == null) {
      throw const FormatException('Legacy model needs the menu catalog');
    }
    final raw = (state as Map)['events'];
    if (raw is! List || raw.length > retainedEvents) {
      throw const FormatException('Invalid learning events');
    }
    final result = <Map<String, dynamic>>[];
    final ids = <String>{};
    if ((state)['sampleCount'] > raw.length) {
      throw const FormatException('Inconsistent learning events');
    }
    for (final item in raw) {
      if (!validEvent(item, legacy: legacy) ||
          !ids.add((item as Map)['id'] as String)) {
        throw const FormatException('Invalid learning event');
      }
      final event = item;
      final age = now.millisecondsSinceEpoch - (event['createdAt'] as int);
      if (age >= 0 && age <= retention.inMilliseconds) {
        final upgraded = Map<String, dynamic>.from(event);
        if (legacy) {
          final menu = catalog![event['menuId']];
          // Deleted/unknown menu IDs cannot be reconstructed. Other preferences
          // and known reactions are preserved; hashed weights are never reused.
          if (menu == null) continue;
          upgraded['features'] = features(
            menu,
            RecommendationRequest(
              mood: event['mood'] as String,
              situation: event['situation'] as String,
              budget: event['budget'] as int,
              spicy: event['spicy'] as String,
            ),
          );
          upgraded['featureVersion'] = LearningProfile.version;
        }
        result.add(upgraded);
      }
    }
    return result;
  }

  /// Retain labelled reactions independently of unlabelled browsing. Reserve
  /// up to 16 pending exposures so a recently displayed menu can receive a
  /// reaction later; unlabelled traffic cannot evict the other 48 samples.
  static List<Map<String, dynamic>> retainEvents(
    List<Map<String, dynamic>> events,
  ) {
    int order(Map<String, dynamic> a, Map<String, dynamic> b) {
      final time = (a['createdAt'] as int).compareTo(b['createdAt'] as int);
      return time == 0
          ? (a['id'] as String).compareTo(b['id'] as String)
          : time;
    }

    final sorted = [...events]..sort(order);
    if (sorted.length <= retainedEvents) return sorted;
    final labelled = sorted.where((e) => label(e) != null).toList();
    final pending = sorted.where((e) => label(e) == null).toList();
    final labelledSlots =
        retainedEvents - min(pendingReserve, pending.length).toInt();
    final keptLabels = labelled.skip(
      max(0, labelled.length - labelledSlots).toInt(),
    );
    final pendingSlots = retainedEvents - keptLabels.length;
    return [
      ...keptLabels,
      ...pending.skip(max(0, pending.length - pendingSlots).toInt()),
    ]..sort(order);
  }

  static Map<String, dynamic> state(List<Map<String, dynamic>> events) {
    final retained = retainEvents(events);
    return {...fit(retained).toMap(), 'events': retained};
  }
}
