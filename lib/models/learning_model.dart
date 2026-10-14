import 'learning_feature_schema.dart';

/// Versioned, account-scoped parameters. These are fitted from explicit
/// feedback, not evidence of actual eating or a calibrated liking probability.
class LearningProfile {
  static const version = LearningFeatureSchema.version;
  static const dimension = LearningFeatureSchema.dimension;
  final int modelVersion;
  final List<double> weights;
  final int sampleCount;
  final int positives;
  final int negatives;
  final int distinctMenus;

  const LearningProfile({
    this.modelVersion = version,
    this.weights = const [],
    this.sampleCount = 0,
    this.positives = 0,
    this.negatives = 0,
    this.distinctMenus = 0,
  });

  bool get hasMixedFeedback => positives > 0 && negatives > 0;
  bool get hasStrongFeedback =>
      hasMixedFeedback && sampleCount >= 8 && distinctMenus >= 3;

  // One-sided reactions are useful evidence, but do not establish a boundary
  // between likes and dislikes. They only receive a small, one-sided bonus.
  bool get ready =>
      modelVersion == version &&
      sampleCount > 0 &&
      positives + negatives == sampleCount &&
      weights.length == dimension &&
      sampleCount >= 4 &&
      distinctMenus >= 2;

  double get mixedConfidence =>
      ready && hasStrongFeedback ? (sampleCount / 24).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() => {
    'version': modelVersion,
    'weights': weights,
    'sampleCount': sampleCount,
    'positives': positives,
    'negatives': negatives,
    'distinctMenus': distinctMenus,
  };

  factory LearningProfile.fromMap(Object? raw) {
    if (raw == null) return const LearningProfile();
    if (raw is! Map || ![1, version].contains(raw['version'])) {
      throw const FormatException('Unsupported learning model');
    }
    final weights = raw['weights'];
    if (weights is! List ||
        weights.length != (raw['version'] == 1 ? 64 : dimension) ||
        weights.any((v) => v is! num || !v.isFinite || v.abs() > 4)) {
      throw const FormatException('Invalid model weights');
    }
    int count(String key) {
      final value = raw[key];
      if (value is! int || value < 0 || value > 64) {
        throw const FormatException('Invalid model counts');
      }
      return value;
    }

    final result = LearningProfile(
      modelVersion: raw['version'] as int,
      weights: List.unmodifiable(weights.map((v) => (v as num).toDouble())),
      sampleCount: count('sampleCount'),
      positives: count('positives'),
      negatives: count('negatives'),
      distinctMenus: count('distinctMenus'),
    );
    if (result.positives + result.negatives != result.sampleCount ||
        result.distinctMenus > result.sampleCount) {
      throw const FormatException('Inconsistent model counts');
    }
    return result;
  }
}

/// Immutable decision context captured before rendering the result.
class RecommendationExposure {
  final String id;
  final String scope;
  final String menuId;
  final String mood;
  final String situation;
  final int budget;
  final String spicy;
  final List<double> features;
  final List<String> candidateIds;
  final double drawProbability;
  final int score;
  final bool learned;
  final int createdAt;
  final int policyVersion;

  RecommendationExposure({
    required this.id,
    required this.scope,
    required this.menuId,
    required this.mood,
    required this.situation,
    required this.budget,
    required this.spicy,
    required List<double> features,
    required List<String> candidateIds,
    required this.drawProbability,
    required this.score,
    required this.learned,
    required this.createdAt,
    this.policyVersion = 1,
  }) : features = List.unmodifiable(features),
       candidateIds = List.unmodifiable(candidateIds);

  Map<String, dynamic> toMap() => {
    'id': id,
    'menuId': menuId,
    'mood': mood,
    'situation': situation,
    'budget': budget,
    'spicy': spicy,
    'features': features,
    'featureVersion': LearningProfile.version,
    'candidateIds': candidateIds,
    'drawProbability': drawProbability,
    'score': score,
    'policy': learned ? 'hybrid-v1' : 'rules-v2',
    if (policyVersion != 1) 'policyVersion': policyVersion,
    'createdAt': createdAt,
    'liked': false,
    'selected': false,
    'disliked': false,
    'feedbackAt': null,
  };
}

enum RecommendationFeedback { like, unlike, select, dislike }
