import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/menu_model.dart';
import 'user_menu_preference_service.dart';

class LocalRecommendService {
  static List<MenuModel>? _cachedMenus;

  /// 데이터셋 로드 및 메뉴 리스트 변환
  static Future<List<MenuModel>> _loadMenus() async {
    if (_cachedMenus != null) return _cachedMenus!;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/data/menus_dataset.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      _cachedMenus = jsonList.map((json) => MenuModel.fromMap(json)).toList();
      return _cachedMenus!;
    } catch (e) {
      print('Error loading menus dataset: $e');
      return [];
    }
  }

  /// 로컬 데이터셋 기반 메뉴 추천 로직
  static Future<MenuModel> recommend({
    required String mood,
    required String situation,
    required int budget,
    String selectedSpicy = '상관없음',
    String? excludeMenuId,
  }) async {
    final allMenus = await _loadMenus();
    if (allMenus.isEmpty) throw '메뉴 데이터를 불러올 수 없습니다.';
    
    // 데이터셋 검색을 위한 mood 변환 ("기분 좋음" -> "기분좋음")
    String searchMood = mood == '기분 좋음' ? '기분좋음' : mood;
    final bool spicyFilter = selectedSpicy != '상관없음';

    // 1. 제외 필터링 전략
    final dislikedIds = await UserMenuPreferenceService.getDislikedMenuIdsForMood(mood);
    
    // 우선순위 1: 싫어요 제외 + 현재 메뉴 제외
    var pool = allMenus.where((m) => !dislikedIds.contains(m.menuId) && m.menuId != excludeMenuId).toList();
    
    // 우선순위 2: 후보가 없으면 현재 메뉴만 제외 (싫어요 포함)
    if (pool.isEmpty && excludeMenuId != null) {
      pool = allMenus.where((m) => m.menuId != excludeMenuId).toList();
    }
    
    // 우선순위 3: 그래도 없으면 전체 메뉴 사용 (최후의 보루)
    if (pool.isEmpty) {
      pool = allMenus;
    }

    // 맵기 조건은 사용자가 "상관없음"이 아닌 값을 선택했을 때 반드시 지키는 하드 필터로 적용한다.
    // 즉, 이후 기분/상황/예산 조건을 완화하더라도 맵기 조건은 절대 완화하지 않는다.
    if (spicyFilter) {
      pool = pool.where((m) => m.spicyLevel == selectedSpicy).toList();

      // 싫어요/현재 메뉴 제외 때문에 후보가 사라진 경우에도 맵기 조건은 유지한 채 제외 조건만 완화한다.
      if (pool.isEmpty) {
        pool = allMenus.where((m) => m.spicyLevel == selectedSpicy).toList();
      }

      // 데이터셋 자체에 해당 맵기 메뉴가 없으면 다른 맵기 메뉴를 추천하지 않고 오류를 반환한다.
      if (pool.isEmpty) {
        throw '$selectedSpicy 맵기에 해당하는 메뉴 데이터가 없습니다.';
      }
    }

    // 사용자 커스텀 태그 정보 가져오기
    final addedIds = await UserMenuPreferenceService.getAddedMoodMenuIds(mood);
    final removedIds = await UserMenuPreferenceService.getRemovedMoodMenuIds(mood);

    // 매칭 헬퍼 함수들
    bool isMoodMatch(MenuModel m) {
      if (removedIds.contains(m.menuId)) return false;
      if (addedIds.contains(m.menuId)) return true;
      return m.moodTags.contains(searchMood) || m.moodTags.contains(mood);
    }
    bool isSituationMatch(MenuModel m) => m.situationTags.contains(situation);
    bool isBudgetMatch(MenuModel m) => m.budgetMin <= budget && m.budgetMax >= budget;

    // 추천 우선순위 검색
    // selectedSpicy가 "상관없음"이 아니면 pool이 이미 해당 맵기 메뉴로만 구성되어 있다.
    // 따라서 아래 fallback 단계에서도 맵기 조건은 계속 유지된다.
    
    // 1순위: 기분 + 상황 + 예산 일치
    var candidates = pool.where((m) => isMoodMatch(m) && isSituationMatch(m) && isBudgetMatch(m)).toList();
    if (candidates.isNotEmpty) return (candidates..shuffle()).first;

    // 2순위: 기분 + 상황 일치
    candidates = pool.where((m) => isMoodMatch(m) && isSituationMatch(m)).toList();
    if (candidates.isNotEmpty) return (candidates..shuffle()).first;

    // 3순위: 기분 + 예산 일치
    candidates = pool.where((m) => isMoodMatch(m) && isBudgetMatch(m)).toList();
    if (candidates.isNotEmpty) return (candidates..shuffle()).first;

    // 4순위: 상황 + 예산 일치
    candidates = pool.where((m) => isSituationMatch(m) && isBudgetMatch(m)).toList();
    if (candidates.isNotEmpty) return (candidates..shuffle()).first;

    // 5순위: 기분 일치
    candidates = pool.where((m) => isMoodMatch(m)).toList();
    if (candidates.isNotEmpty) return (candidates..shuffle()).first;

    // 6순위: 상황 일치
    candidates = pool.where((m) => isSituationMatch(m)).toList();
    if (candidates.isNotEmpty) return (candidates..shuffle()).first;

    // 7순위: 예산 일치
    candidates = pool.where((m) => isBudgetMatch(m)).toList();
    if (candidates.isNotEmpty) return (candidates..shuffle()).first;

    // 8순위 Fallback: 기분/상황/예산이 맞지 않아도 pool 내부에서 랜덤 추천
    // 맵기 선택이 있는 경우 pool 자체가 해당 맵기 메뉴로만 구성되어 있으므로 맵기는 반드시 유지된다.
    return (pool..shuffle()).first;
  }

  /// 전체 메뉴 중 하나를 랜덤으로 추천 (조건 없음)
  static Future<MenuModel> recommendRandom({String? excludeMenuId}) async {
    final allMenus = await _loadMenus();
    if (allMenus.isEmpty) throw '메뉴 데이터를 불러올 수 없습니다.';

    var pool = allMenus;

    // 명시적 제외 메뉴 처리
    if (excludeMenuId != null) {
      pool = allMenus.where((m) => m.menuId != excludeMenuId).toList();
    }

    // 후보가 없으면 (데이터가 1개뿐인데 제외된 경우 등) 전체에서 반환
    if (pool.isEmpty) {
      pool = allMenus;
    }

    return (pool..shuffle()).first;
  }

  /// 모든 메뉴 목록 반환 (관리용)
  static Future<List<MenuModel>> getAllMenus() async {
    return await _loadMenus();
  }
}
