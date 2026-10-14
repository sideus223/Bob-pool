import 'package:flutter/material.dart';
import '../models/menu_model.dart';
import '../services/local_recommend_service.dart';
import '../services/user_menu_preference_service.dart';

class MoodFoodManagePage extends StatefulWidget {
  const MoodFoodManagePage({super.key});

  @override
  State<MoodFoodManagePage> createState() => _MoodFoodManagePageState();
}

class _MoodFoodManagePageState extends State<MoodFoodManagePage> {
  final List<String> moods = ["기분 좋음", "무난함", "우울함", "스트레스", "피곤함"];
  String selectedMood = "기분 좋음";

  List<MenuModel> allMenus = [];
  List<String> addedIds = [];
  List<String> removedIds = [];
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  int _loadVersion = 0;
  String? _error;

  Future<void> _loadData() async {
    final version = ++_loadVersion;
    final mood = selectedMood;
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final menus = await LocalRecommendService.getAllMenus();
      final preferences = await UserMenuPreferenceService.snapshot(mood);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        allMenus = menus;
        addedIds = preferences.added.toList();
        removedIds = preferences.removed.toList();
      });
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = '정보를 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleMood(MenuModel menu) async {
    final mood = selectedMood;
    final isCurrentlyIn = _isMenuInSelectedMood(menu);
    setState(() => isLoading = true);
    try {
      if (isCurrentlyIn) {
        await UserMenuPreferenceService.removeMoodForMenu(
          menuId: menu.menuId,
          mood: mood,
        );
      } else {
        await UserMenuPreferenceService.addMoodForMenu(
          menuId: menu.menuId,
          mood: mood,
        );
      }
      if (mounted) await _loadData();
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _error = '저장하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  bool _isMenuInSelectedMood(MenuModel menu) {
    if (removedIds.contains(menu.menuId)) return false;
    if (addedIds.contains(menu.menuId)) return true;

    String searchMood = selectedMood == "기분 좋음" ? "기분좋음" : selectedMood;
    return menu.moodTags.contains(searchMood) ||
        menu.moodTags.contains(selectedMood);
  }

  Future<void> _resetMood() async {
    final mood = selectedMood;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: Text('\'$selectedMood\' 기분의 음식 설정과 별로예요 기록을 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    try {
      await UserMenuPreferenceService.clearMoodCustomizations(mood);
      if (mounted) await _loadData();
    } catch (_) {
      if (mounted) setState(() => _error = '초기화하지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    List<MenuModel> filteredMenus = allMenus.where((m) {
      final matchesSearch =
          m.menuName.contains(searchQuery) || m.category.contains(searchQuery);
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      appBar: AppBar(
        title: const Text(
          '기분별 음식 관리',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF32201C),
        actions: [
          IconButton(
            onPressed: _resetMood,
            icon: const Icon(Icons.refresh),
            tooltip: '초기화',
          ),
        ],
      ),
      body: Column(
        children: [
          // 기분 선택 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: moods.map((mood) {
                bool isSelected = selectedMood == mood;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(mood),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => selectedMood = mood);
                        _loadData();
                      }
                    },
                    selectedColor: const Color(0xFFFD5D69),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF32201C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: '음식 검색...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 메뉴 목록
          Expanded(
            child: _error != null
                ? Center(
                    child: TextButton(
                      onPressed: _loadData,
                      child: Text(_error!),
                    ),
                  )
                : isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredMenus.length,
                    itemBuilder: (context, index) {
                      final menu = filteredMenus[index];
                      final bool isInMood = _isMenuInSelectedMood(menu);
                      final bool isAdded = addedIds.contains(menu.menuId);
                      final bool isRemoved = removedIds.contains(menu.menuId);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              menu.imageAssetPath,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.fastfood,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  menu.menuName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isAdded) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  '내가 추가함',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              if (isRemoved) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  '제외됨',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(menu.category),
                          trailing: ElevatedButton(
                            onPressed: () => _toggleMood(menu),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isInMood
                                  ? Colors.grey[200]
                                  : const Color(0xFFFD5D69),
                              foregroundColor: isInMood
                                  ? const Color(0xFF32201C)
                                  : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              isInMood ? '제거' : '추가',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
