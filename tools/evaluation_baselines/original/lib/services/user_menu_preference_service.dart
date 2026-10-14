import 'package:shared_preferences/shared_preferences.dart';

class UserMenuPreferenceService {
  static const String _dislikePrefix = 'disliked_menus_';
  static const String _likePrefix = 'liked_menus_';
  static const String _addedMoodPrefix = 'added_mood_';
  static const String _removedMoodPrefix = 'removed_mood_';

  /// 특정 기분에서 메뉴 '별로예요' 처리
  static Future<void> dislikeMenuForMood({required String mood, required String menuId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dislikePrefix$mood';
    List<String> dislikedList = prefs.getStringList(key) ?? [];
    if (!dislikedList.contains(menuId)) {
      dislikedList.add(menuId);
      await prefs.setStringList(key, dislikedList);
    }
  }

  /// 특정 기분에서 '별로예요'한 메뉴 ID 목록 가져오기
  static Future<List<String>> getDislikedMenuIdsForMood(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dislikePrefix$mood';
    return prefs.getStringList(key) ?? [];
  }

  /// 메뉴 '좋아요' 처리 (찜하기 기능으로 통합 사용 가능)
  static Future<void> likeMenu({required String menuId}) async {
    await addFavoriteMenu(menuId);
  }

  /// 특정 기분의 싫어요 목록 초기화
  static Future<void> clearDislikedMenusForMood(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dislikePrefix$mood';
    await prefs.remove(key);
  }

  // --- 기분별 음식 커스터마이징 기능 ---

  /// 특정 기분에 메뉴 추가
  static Future<void> addMoodForMenu({required String menuId, required String mood}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 제거 목록에 있다면 제거
    final removedKey = '$_removedMoodPrefix$mood';
    List<String> removedList = prefs.getStringList(removedKey) ?? [];
    if (removedList.contains(menuId)) {
      removedList.remove(menuId);
      await prefs.setStringList(removedKey, removedList);
    }

    // 추가 목록에 넣기
    final addedKey = '$_addedMoodPrefix$mood';
    List<String> addedList = prefs.getStringList(addedKey) ?? [];
    if (!addedList.contains(menuId)) {
      addedList.add(menuId);
      await prefs.setStringList(addedKey, addedList);
    }
  }

  /// 특정 기분에서 메뉴 제거
  static Future<void> removeMoodForMenu({required String menuId, required String mood}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 추가 목록에 있다면 제거
    final addedKey = '$_addedMoodPrefix$mood';
    List<String> addedList = prefs.getStringList(addedKey) ?? [];
    if (addedList.contains(menuId)) {
      addedList.remove(menuId);
      await prefs.setStringList(addedKey, addedList);
    }

    // 제거 목록에 넣기
    final removedKey = '$_removedMoodPrefix$mood';
    List<String> removedList = prefs.getStringList(removedKey) ?? [];
    if (!removedList.contains(menuId)) {
      removedList.add(menuId);
      await prefs.setStringList(removedKey, removedList);
    }
  }

  /// 특정 기분에 사용자가 추가한 menuId 목록 반환
  static Future<List<String>> getAddedMoodMenuIds(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_addedMoodPrefix$mood';
    return prefs.getStringList(key) ?? [];
  }

  /// 특정 기분에서 사용자가 제거한 menuId 목록 반환
  static Future<List<String>> getRemovedMoodMenuIds(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_removedMoodPrefix$mood';
    return prefs.getStringList(key) ?? [];
  }

  /// 특정 메뉴가 특정 기분에 추가되었는지 확인
  static Future<bool> isMenuAddedToMood({required String menuId, required String mood}) async {
    final addedIds = await getAddedMoodMenuIds(mood);
    return addedIds.contains(menuId);
  }

  /// 특정 메뉴가 특정 기분에서 제거되었는지 확인
  static Future<bool> isMenuRemovedFromMood({required String menuId, required String mood}) async {
    final removedIds = await getRemovedMoodMenuIds(mood);
    return removedIds.contains(menuId);
  }

  /// 특정 기분의 추가/제거 설정 초기화
  static Future<void> clearMoodCustomizations(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_addedMoodPrefix$mood');
    await prefs.remove('$_removedMoodPrefix$mood');
  }

  // --- 찜한 메뉴 (즐겨찾기) 기능 ---

  /// 저장된 찜한 메뉴 ID 목록 반환
  static Future<List<String>> getFavoriteMenuIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_likePrefix) ?? [];
  }

  /// 찜한 메뉴에 추가
  static Future<void> addFavoriteMenu(String menuId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_likePrefix) ?? [];
    if (!favorites.contains(menuId)) {
      favorites.add(menuId);
      await prefs.setStringList(_likePrefix, favorites);
    }
  }

  /// 찜한 메뉴에서 제거
  static Future<void> removeFavoriteMenu(String menuId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_likePrefix) ?? [];
    if (favorites.contains(menuId)) {
      favorites.remove(menuId);
      await prefs.setStringList(_likePrefix, favorites);
    }
  }

  /// 해당 메뉴가 찜한 메뉴인지 확인
  static Future<bool> isFavoriteMenu(String menuId) async {
    final favorites = await getFavoriteMenuIds();
    return favorites.contains(menuId);
  }

  /// 찜한 메뉴 전체 삭제
  static Future<void> clearFavoriteMenus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_likePrefix);
  }
}
