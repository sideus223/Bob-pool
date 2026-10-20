import 'package:flutter/material.dart';
import '../models/menu_model.dart';
import '../services/local_recommend_service.dart';
import '../services/user_menu_preference_service.dart';
import '../routes/app_routes.dart';

class FavoriteMenuPage extends StatefulWidget {
  const FavoriteMenuPage({super.key});

  @override
  State<FavoriteMenuPage> createState() => _FavoriteMenuPageState();
}

class _FavoriteMenuPageState extends State<FavoriteMenuPage> {
  List<MenuModel> favoriteMenus = [];
  bool isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavoriteMenus();
  }

  Future<void> _loadFavoriteMenus() async {
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final favoriteIds = await UserMenuPreferenceService.getFavoriteMenuIds();
      final allMenus = await LocalRecommendService.getAllMenus();

      if (!mounted) return;
      setState(() {
        favoriteMenus = allMenus
            .where((m) => favoriteIds.contains(m.menuId))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '찜한 메뉴를 불러오지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _removeFavorite(String menuId) async {
    try {
      await UserMenuPreferenceService.removeFavoriteMenu(menuId);
      if (mounted) await _loadFavoriteMenus();
    } catch (_) {
      if (mounted) setState(() => _error = '찜을 해제하지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '찜한 메뉴',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF32201C),
      ),
      body: _error != null
          ? Center(
              child: TextButton(
                onPressed: _loadFavoriteMenus,
                child: Text(_error!),
              ),
            )
          : isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFD5D69)),
            )
          : favoriteMenus.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: favoriteMenus.length,
              itemBuilder: (context, index) {
                final menu = favoriteMenus[index];
                return _buildFavoriteCard(menu);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          const Text(
            '아직 찜한 메뉴가 없습니다.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF32201C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '추천 결과에서 좋아요를 누르면 여기에 저장돼요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(MenuModel menu) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.asset(
              menu.imageAssetPath,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            menu.menuName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF32201C),
                            ),
                          ),
                          Text(
                            menu.category,
                            style: const TextStyle(
                              color: Color(0xFFFD5D69),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: Color(0xFFFD5D69),
                      ),
                      onPressed: () => _removeFavorite(menu.menuId),
                      tooltip: '찜 해제',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCompactInfoGrid(menu),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _removeFavorite(menu.menuId),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('찜 해제'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.recipe,
                            arguments: menu,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFD5D69),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '레시피 보기',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoGrid(MenuModel menu) {
    final infoItems = [
      {'icon': Icons.payments_outlined, 'label': '₩${menu.budgetMin}~'},
      {'icon': Icons.whatshot_outlined, 'label': menu.spicyLevel},
      {'icon': Icons.sentiment_satisfied_alt_outlined, 'label': menu.fullness},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: infoItems
          .map(
            (item) => Row(
              children: [
                Icon(item['icon'] as IconData, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  item['label'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF32201C),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}
