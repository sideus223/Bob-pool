import '../models/menu_model.dart';
import '../models/recommendation_model.dart';

/// A soft penalty against the most recently exposed food family. Hard filters
/// and the candidate pool stay intact, including when every menu is similar.
class RecommendationDiversity {
  static const weight = -12;
  static const window = Duration(hours: 24);
  static MenuModel? lastMenu(
    List<MenuModel> menus,
    Map<String, MenuInteractionHistory> history,
    DateTime now,
  ) {
    MenuModel? latest;
    DateTime? latestTime;
    for (final menu in menus) {
      final time = history[menu.menuId]?.lastRecommendedAt;
      if (time == null || time.isAfter(now) || now.difference(time) >= window) {
        continue;
      }
      if (latestTime == null ||
          time.isAfter(latestTime) ||
          (time == latestTime && menu.menuId.compareTo(latest!.menuId) < 0)) {
        latest = menu;
        latestTime = time;
      }
    }
    return latest;
  }

  static bool similar(MenuModel menu, MenuModel? previous) {
    if (previous == null || previous.menuId == menu.menuId) return false;
    final a = menu.foodTraits;
    final b = previous.foodTraits;
    if (!a.isComplete || !b.isComplete || a.foodForm != b.foodForm) {
      return false;
    }
    // Plate/snack/rice cover very different meals. Require the same cooking
    // method there; noodle, soup, bread and salad are already a useful family.
    return ['면', '국물', '빵', '샐러드'].contains(a.foodForm) ||
        a.cookingMethod == b.cookingMethod;
  }
}
