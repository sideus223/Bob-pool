import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/local_recommend_service.dart';
import '../models/menu_model.dart';
import '../models/recommendation_model.dart';
import '../models/learning_model.dart';
import '../widgets/bottom_nav_bar.dart';

class RandomMenuPickerPage extends StatefulWidget {
  const RandomMenuPickerPage({super.key});

  @override
  State<RandomMenuPickerPage> createState() => _RandomMenuPickerPageState();
}

class _RandomMenuPickerPageState extends State<RandomMenuPickerPage> {
  bool isRandomMode = false; // 기본값 맞춤 추천 (false)
  String selectedMood = "무난함";
  String selectedSituation = "혼밥";
  String selectedSpicy = "상관없음";
  double maxBudget = 25000;
  bool _isLoading = false;

  // 프로젝트 확정 기분 상태 5개
  final List<Map<String, String>> moodData = [
    {"label": "기분 좋음", "emoji": "😊"},
    {"label": "무난함", "emoji": "😐"},
    {"label": "우울함", "emoji": "😢"},
    {"label": "스트레스", "emoji": "😤"},
    {"label": "피곤함", "emoji": "😔"},
  ];

  // 상황 선택지 (데이터셋 기준)
  final List<Map<String, String>> situations = [
    {"label": "혼밥", "emoji": "🍚", "value": "혼밥"},
    {"label": "친구랑", "emoji": "👥", "value": "친구랑"},
    {"label": "데이트", "emoji": "💕", "value": "데이트"},
    {"label": "든든하게", "emoji": "🍱", "value": "든든하게"},
    {"label": "가볍게", "emoji": "🥗", "value": "가볍게"},
    {"label": "빨리먹기", "emoji": "⏱️", "value": "빨리먹기"},
  ];

  // 맵기 선택지
  final List<String> spicyLevels = ["상관없음", "순함", "보통", "매움"];

  Future<void> _handleRecommend() async {
    setState(() {
      _isLoading = true;
    });

    try {
      MenuModel result;
      RankedMenu? ranked;
      RecommendationExposure? exposure;
      if (isRandomMode) {
        result = await LocalRecommendService.recommendRandom();
      } else {
        final candidates = await LocalRecommendService.rank(
          RecommendationRequest(
            mood: selectedMood,
            situation: selectedSituation,
            budget: maxBudget.toInt(),
            spicy: selectedSpicy,
          ),
        );
        if (candidates.isEmpty) {
          throw const NoRecommendationException(
            '조건에 맞는 메뉴가 없어요. 예산이나 맵기를 직접 변경해 주세요.',
          );
        }
        final choice = LocalRecommendService.pickWithExposure(
          candidates,
          RecommendationRequest(
            mood: selectedMood,
            situation: selectedSituation,
            budget: maxBudget.toInt(),
            spicy: selectedSpicy,
          ),
        );
        ranked = choice.result;
        exposure = choice.exposure;
        result = ranked.menu;
      }

      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.recommendResult,
          arguments: {
            'menu': result,
            'ranked': ranked,
            'exposure': exposure,
            'mood': isRandomMode ? null : selectedMood,
            'situation': isRandomMode ? null : selectedSituation,
            'budget': isRandomMode ? null : maxBudget.toInt(),
            'selectedSpicy': isRandomMode ? "상관없음" : selectedSpicy,
            'isRandomMode': isRandomMode,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추천 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF9),
        appBar: AppBar(
          title: const Text(
            '메뉴 추천',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF32201C),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSelectionView(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 1),
      ),
    );
  }

  Widget _buildSelectionView() {
    double buttonWidth = (MediaQuery.of(context).size.width - 48 - 40 - 12) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 추천 방식 선택 UI
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC6C9).withAlpha(77),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => setState(() => isRandomMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !isRandomMode
                          ? const Color(0xFFFD5D69)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '맞춤 추천',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !isRandomMode
                            ? Colors.white
                            : const Color(0xFF32201C),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => setState(() => isRandomMode = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isRandomMode
                          ? const Color(0xFFFD5D69)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '랜덤 추천',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRandomMode
                            ? Colors.white
                            : const Color(0xFF32201C),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 맞춤 추천 선택 시에만 표시되는 영역
        if (!isRandomMode) ...[
          _buildSectionCard(
            '오늘 기분은 어때요? 😊',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: moodData
                  .map(
                    (m) => SizedBox(
                      width: buttonWidth,
                      child: _moodButton(m['label']!, m['emoji']!, m['label']!),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            '오늘의 상황은? 🎯',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: situations
                  .map(
                    (s) => SizedBox(
                      width: buttonWidth,
                      child: _situationButton(
                        s['label']!,
                        s['emoji']!,
                        s['value']!,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            '맵기 정도를 골라주세요 🔥',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: spicyLevels.map((level) {
                bool isSelected = selectedSpicy == level;
                return GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => setState(() => selectedSpicy = level),
                  child: Container(
                    width:
                        (MediaQuery.of(context).size.width - 48 - 40 - 24) / 4,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFD5D69)
                          : const Color(0xFFFFC6C9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      level,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFFD5D69),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            '최대 예산은? 💰',
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '최대 금액',
                      style: TextStyle(color: Color(0xFFEC888D)),
                    ),
                    Text(
                      '₩${maxBudget.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFD5D69),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: maxBudget,
                  min: 5000,
                  max: 50000,
                  divisions: 45,
                  activeColor: const Color(0xFFFD5D69),
                  inactiveColor: const Color(0xFFFFC6C9),
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => maxBudget = value),
                ),
                const Text(
                  '메뉴의 예상 가격 상한이 이 금액 이내인 경우만 추천해요.',
                  style: TextStyle(fontSize: 12),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₩5,000',
                      style: TextStyle(fontSize: 12, color: Color(0xFFEC888D)),
                    ),
                    Text(
                      '₩50,000',
                      style: TextStyle(fontSize: 12, color: Color(0xFFEC888D)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          // 랜덤 추천 모드일 때 보여줄 간단한 안내나 빈 공간
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.casino_outlined, size: 64, color: Color(0xFFFD5D69)),
                SizedBox(height: 16),
                Text(
                  '고민할 필요 없어요!\n주사위를 굴려 랜덤으로 메뉴를 추천해 드릴게요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF32201C),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleRecommend,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.casino_outlined),
          label: Text(
            _isLoading ? '추천 중...' : (isRandomMode ? '아무거나 추천받기' : '추천받기'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFD5D69),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF32201C),
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _moodButton(String label, String emoji, String value) {
    bool isSelected = selectedMood == value;
    return GestureDetector(
      onTap: _isLoading ? null : () => setState(() => selectedMood = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFD5D69) : const Color(0xFFFFC6C9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFFFD5D69),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _situationButton(String label, String emoji, String value) {
    bool isSelected = selectedSituation == value;
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () => setState(() => selectedSituation = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFD5D69) : const Color(0xFFFFC6C9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFFFD5D69),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
