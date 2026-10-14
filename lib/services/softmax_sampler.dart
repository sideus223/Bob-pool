import 'dart:math';
import '../models/recommendation_model.dart';

/// Samples only the already-filtered candidates. Ranking stays read-only and
/// deterministic; an injected RNG makes the draw reproducible in tests.
class SoftmaxSampler {
  static const defaultTemperature = 10.0;
  static const defaultExplorationRate = 0.1;

  List<MenuProbability> distribution(
    List<RankedMenu> candidates, {
    double temperature = defaultTemperature,
    double explorationRate = 0,
  }) {
    if (!temperature.isFinite || temperature <= 0) {
      throw ArgumentError.value(
        temperature,
        'temperature',
        'Must be finite and positive',
      );
    }
    if (!explorationRate.isFinite ||
        explorationRate < 0 ||
        explorationRate > 1) {
      throw ArgumentError.value(
        explorationRate,
        'explorationRate',
        'Must be 0..1',
      );
    }
    if (candidates.isEmpty) return const [];
    final maxScore = candidates.map((candidate) => candidate.score).reduce(max);
    // Subtracting the maximum leaves probabilities unchanged and avoids exp
    // overflow. At least one weight is 1, including for all-negative scores.
    final weights = candidates
        .map((candidate) => exp((candidate.score - maxScore) / temperature))
        .toList();
    final total = weights.fold(0.0, (sum, weight) => sum + weight);
    final eligible = candidates.where((item) => item.explorationEligible);
    final leastCount = eligible.isEmpty
        ? null
        : eligible.map((item) => item.exposureCount).reduce(min);
    final leastExposed = eligible.isEmpty
        ? const <String>{}
        : {
            for (final item in eligible)
              if (item.exposureCount == leastCount) item.menu.menuId,
          };
    final rate = leastExposed.isEmpty ? 0.0 : explorationRate;
    return List.unmodifiable([
      for (int index = 0; index < candidates.length; index++)
        MenuProbability(
          candidates[index],
          (1 - rate) * weights[index] / total +
              (leastExposed.contains(candidates[index].menu.menuId)
                  ? rate / leastExposed.length
                  : 0),
        ),
    ]);
  }

  RankedMenu draw(
    List<RankedMenu> candidates, {
    double temperature = defaultTemperature,
    double explorationRate = 0,
    Random? random,
  }) {
    final probabilities = distribution(
      candidates,
      temperature: temperature,
      explorationRate: explorationRate,
    );
    if (probabilities.isEmpty) {
      throw const NoRecommendationException('조건에 맞는 메뉴가 없습니다.');
    }
    final target = (random ?? Random()).nextDouble();
    double cumulative = 0;
    RankedMenu? lastPositive;
    for (final entry in probabilities) {
      if (entry.probability <= 0) continue;
      lastPositive = entry.candidate;
      cumulative += entry.probability;
      if (target < cumulative) return entry.candidate;
    }
    // Only for floating-point rounding near 1; never select a zero-weight entry.
    return lastPositive!;
  }
}
