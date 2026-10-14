import '../models/menu_model.dart';
import 'local_recommend_service.dart';

/// 기존 코드 호환용 래퍼입니다.
/// 실제 추천은 서버 API가 아니라 LocalRecommendService가 담당합니다.
class RecommendService {
  static Future<MenuModel> recommendV2({
    required String mood,
    required String situation,
    required double budget,
  }) {
    return LocalRecommendService.recommend(
      mood: mood,
      situation: situation,
      budget: budget.toInt(),
    );
  }

  static Future<MenuModel> recommend({
    required String mood,
    required String goal,
    required double budget,
  }) {
    return LocalRecommendService.recommend(
      mood: mood,
      situation: goal,
      budget: budget.toInt(),
    );
  }
}
