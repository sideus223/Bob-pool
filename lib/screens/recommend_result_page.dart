import 'package:flutter/material.dart';
import '../models/menu_model.dart';
import '../models/recommendation_model.dart';
import '../models/learning_model.dart';
import '../routes/app_routes.dart';
import '../services/local_recommend_service.dart';
import '../services/user_menu_preference_service.dart';
import '../core/app_config.dart';
import '../widgets/menu_summary_card.dart';
import '../widgets/recommendation/result_decision_buttons.dart';

class RecommendResultPage extends StatefulWidget {
  const RecommendResultPage({super.key});
  @override
  State<RecommendResultPage> createState() => _RecommendResultPageState();
}

class _RecommendResultPageState extends State<RecommendResultPage> {
  MenuModel? _menu;
  RecommendationRequest? _request;
  RecommendationExposure? _exposure;
  final Set<String> _shown = {};
  bool _initialized = false;
  bool _random = false;
  bool _busy = false;
  bool _favorite = false;
  bool _selected = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic> || args['menu'] is! MenuModel) return;
    _menu = args['menu'] as MenuModel;
    _random = args['isRandomMode'] == true;
    _exposure = _random ? null : args['exposure'] as RecommendationExposure?;
    if (!_random) {
      _request = RecommendationRequest(
        mood: args['mood'] as String? ?? '무난함',
        situation: args['situation'] as String? ?? '혼밥',
        budget: args['budget'] as int? ?? 25000,
        spicy: args['selectedSpicy'] as String? ?? '상관없음',
      );
    }
    _shown.add(_menu!.menuId);
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final menuId = _menu!.menuId;
    _busy = true;
    try {
      if (_exposure != null) {
        await UserMenuPreferenceService.recordExposure(_exposure!);
      } else {
        await UserMenuPreferenceService.recordRecommendation(menuId);
      }
      final favorite = await UserMenuPreferenceService.isFavoriteMenu(menuId);
      if (mounted && _menu?.menuId == menuId) {
        setState(() => _favorite = favorite);
      }
    } catch (_) {
      if (mounted) setState(() => _message = '찜 정보를 불러오지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next({bool dislike = false}) => _run(() async {
    if (dislike && _request != null) {
      if (_exposure != null) {
        await UserMenuPreferenceService.recommendationFeedback(
          _exposure!,
          RecommendationFeedback.dislike,
        );
      } else {
        await UserMenuPreferenceService.dislikeMenuForMood(
          mood: _request!.mood,
          menuId: _menu!.menuId,
        );
      }
    }
    MenuModel next;
    RecommendationExposure? exposure;
    if (_random) {
      next = await LocalRecommendService.recommendRandom(
        excludeMenuId: _menu!.menuId,
      );
    } else {
      final candidates = await LocalRecommendService.rank(
        _request!,
        excludedIds: _shown,
      );
      if (candidates.isEmpty) {
        throw const NoRecommendationException(
          '조건에 맞는 메뉴를 모두 확인했어요. 뒤로 가서 조건을 변경해 주세요.',
        );
      }
      final choice = LocalRecommendService.pickWithExposure(
        candidates,
        _request!,
      );
      exposure = choice.exposure;
      next = choice.result.menu;
    }
    final favorite = await UserMenuPreferenceService.isFavoriteMenu(
      next.menuId,
    );
    if (!mounted) return;
    if (exposure != null) {
      await UserMenuPreferenceService.recordExposure(exposure);
    } else {
      await UserMenuPreferenceService.recordRecommendation(next.menuId);
    }
    if (!mounted) return;
    setState(() {
      _menu = next;
      _exposure = exposure;
      _favorite = favorite;
      _selected = false;
      _shown.add(next.menuId);
    });
  });

  Future<void> _toggleFavorite() => _run(() async {
    if (_exposure != null) {
      await UserMenuPreferenceService.recommendationFeedback(
        _exposure!,
        _favorite ? RecommendationFeedback.unlike : RecommendationFeedback.like,
      );
    } else if (_favorite) {
      await UserMenuPreferenceService.removeFavoriteMenu(_menu!.menuId);
    } else {
      await UserMenuPreferenceService.addFavoriteMenu(_menu!.menuId);
    }
    if (mounted) setState(() => _favorite = !_favorite);
  });

  Future<void> _select() => _run(() async {
    if (_selected) return;
    if (_exposure != null) {
      await UserMenuPreferenceService.recommendationFeedback(
        _exposure!,
        RecommendationFeedback.select,
      );
    } else {
      await UserMenuPreferenceService.recordSelection(_menu!.menuId);
    }
    if (!mounted) return;
    setState(() => _selected = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('선택을 기록했어요. 다음 맞춤 추천에 반영됩니다.')),
    );
  });

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    return Scaffold(
      appBar: AppBar(title: Text(_random ? '랜덤 추천 결과' : '나를 위한 추천')),
      bottomNavigationBar: menu == null
          ? null
          : ResultDecisionButtons(
              busy: _busy,
              selected: _selected,
              onSelect: _select,
              onNext: () => _next(),
            ),
      body: menu == null
          ? const Center(child: Text('추천 화면에서 메뉴를 먼저 선택해 주세요.'))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  MenuSummaryCard(menu: menu),
                  const SizedBox(height: 4),
                  if (_random)
                    const Text('전체 메뉴에서 무작위로 골랐어요. 예산·맵기·취향 조건은 적용되지 않아요.'),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('레시피 보기'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _busy
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            AppRoutes.recipe,
                            arguments: menu,
                          ),
                  ),
                  const Divider(height: 1),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    '평소 취향은 어때요?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _toggleFavorite,
                          icon: Icon(
                            _favorite ? Icons.favorite : Icons.favorite_border,
                          ),
                          label: Text(_favorite ? '찜 해제' : '좋아요 · 찜'),
                        ),
                      ),
                      if (!_random) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _next(dislike: true),
                            icon: const Icon(Icons.thumb_down_outlined),
                            label: const Text('별로예요'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 12),
                  Text(
                    '가격은 메뉴 데이터의 예상 범위이며 실제 판매 가격과 다를 수 있어요. '
                    '${AppConfig.demoMode ? '데모의 취향과 선택 기록은 이 기기에 저장됩니다.' : '취향과 선택 기록은 로그인한 계정에 저장됩니다.'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}
