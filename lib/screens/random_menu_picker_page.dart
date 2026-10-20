import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/local_recommend_service.dart';
import '../models/menu_model.dart';
import '../models/recommendation_model.dart';
import '../models/learning_model.dart';
import '../widgets/bottom_nav_bar.dart';
import '../core/theme/app_theme.dart';
import '../services/visual_preferences.dart';
import '../widgets/recommendation/bobpool_cooker.dart';
import '../widgets/recommendation/recommendation_controls.dart';

class RandomMenuPickerPage extends StatefulWidget {
  const RandomMenuPickerPage({super.key});

  @override
  State<RandomMenuPickerPage> createState() => _RandomMenuPickerPageState();
}

class _RandomMenuPickerPageState extends State<RandomMenuPickerPage>
    with SingleTickerProviderStateMixin {
  bool isRandomMode = false; // 기본값 맞춤 추천 (false)
  String selectedMood = "무난함";
  String selectedSituation = "혼밥";
  String selectedSpicy = "상관없음";
  double maxBudget = 25000;
  bool _isLoading = false;

  bool _skipAnimation = false;
  bool _settingsReady = false;
  bool _savingPreference = false;
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final value = await VisualPreferences.skipAnimation();
      if (mounted) {
        setState(() {
          _skipAnimation = value;
          _settingsReady = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _settingsReady = true);
    }
  }

  Future<void> _changeSetting(bool? value) async {
    if (value == null || _savingPreference) return;
    final previous = _skipAnimation;
    setState(() {
      _skipAnimation = value;
      _savingPreference = true;
    });
    try {
      await VisualPreferences.setSkipAnimation(value);
    } catch (_) {
      if (mounted) {
        setState(() => _skipAnimation = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정을 저장하지 못했어요. 다시 선택해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPreference = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (var i = 0; i < 8; i++) {
      precacheImage(AssetImage(BobpoolCooker.frameAsset(i)), context);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _handleRecommend() async {
    if (_isLoading || !_settingsReady || _savingPreference) return;
    setState(() {
      _isLoading = true;
    });

    final motion = _skipAnimation
        ? Future<void>.value()
        : _motion.forward(from: 0).orCancel;
    final animationDone = motion.catchError((Object _) {});
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

      await animationDone;
      if (mounted) {
        await Navigator.pushNamed(
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
        _motion.stop(canceled: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('추천 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        _motion.stop(canceled: false);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _isLoading || !_settingsReady || _savingPreference;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('메뉴 추천')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppTheme.primaryColor,
                      selectedForegroundColor: Colors.white,
                      backgroundColor: AppTheme.panelColor,
                      side: const BorderSide(color: AppTheme.lineColor),
                    ),
                    segments: const [
                      ButtonSegment(value: false, label: Text('맞춤 추천')),
                      ButtonSegment(value: true, label: Text('랜덤 추천')),
                    ],
                    selected: {isRandomMode},
                    onSelectionChanged: _isLoading
                        ? null
                        : (value) => setState(() => isRandomMode = value.first),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading && !_skipAnimation
                    ? Center(
                        child: Semantics(
                          label: '밥풀이가 메뉴를 추천하고 있어요',
                          liveRegion: true,
                          child: BobpoolCooker(animation: _motion, size: 280),
                        ),
                      )
                    : isRandomMode
                    ? LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      BobpoolCooker(size: 240),
                                      SizedBox(height: 20),
                                      Text(
                                        '고민 없이, 한 끼 뽑기',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 27,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        '예산 · 맵기 · 취향 조건 없이\n전체 메뉴에서 무작위로 골라요.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.7,
                                          color: AppTheme.mutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AbsorbPointer(
                          absorbing: _isLoading,
                          child: RecommendationControls(
                            mood: selectedMood,
                            situation: selectedSituation,
                            spicy: selectedSpicy,
                            budget: maxBudget,
                            onMood: (v) => setState(() => selectedMood = v),
                            onSituation: (v) =>
                                setState(() => selectedSituation = v),
                            onSpicy: (v) => setState(() => selectedSpicy = v),
                            onBudget: (v) => setState(() => maxBudget = v),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isRandomMode && !_isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$selectedMood · $selectedSituation · 맵기 $selectedSpicy',
                          key: const ValueKey('selected-conditions'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD5374D),
                          ),
                        ),
                      ),
                    CheckboxListTile(
                      key: const ValueKey('skip-recommendation-animation'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _skipAnimation,
                      onChanged: disabled ? null : _changeSetting,
                      title: const Text(
                        '애니메이션 건너뛰기',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.mutedColor,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: disabled ? null : _handleRecommend,
                      icon: _isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.casino_outlined),
                      label: Text(
                        _isLoading
                            ? '추천 중...'
                            : isRandomMode
                            ? '아무거나 추천받기'
                            : '이 조건으로 추천받기',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomNavBar(currentIndex: 1),
      ),
    );
  }
}
