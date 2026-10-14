class MenuModel {
  final String menuId;
  final String menuName;
  final String category;
  final List<String> moodTags;
  final List<String> situationTags;
  final int budgetMin;
  final int budgetMax;
  final String spicyLevel;
  final String fullness;
  final bool cookable;
  final bool eatOut;
  final String recommendText;
  final List<String> ingredients;
  final List<String> recipeSteps;

  // Asset path getter for menu images
  String get imageAssetPath {
    final numberText = menuId.replaceAll(RegExp(r'[^0-9]'), '');
    final number = int.tryParse(numberText) ?? 1;
    return 'assets/images/menus/$number.jpg';
  }

  // Legacy/UI compatibility getters
  String get id => menuId;
  String get name => menuName;
  String get recommendReason => recommendText;
  String get image => ''; 
  String get price => '₩$budgetMin ~ ₩$budgetMax';
  String get rating => '4.5';
  Map<String, String> get nutrition => {};

  MenuModel({
    required this.menuId,
    required this.menuName,
    required this.category,
    this.moodTags = const [],
    this.situationTags = const [],
    this.budgetMin = 0,
    this.budgetMax = 0,
    this.spicyLevel = '보통',
    this.fullness = '보통',
    this.cookable = false,
    this.eatOut = false,
    required this.recommendText,
    this.ingredients = const [],
    this.recipeSteps = const [],
  });

  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      menuId: _toString(map['menu_id'] ?? map['id']),
      menuName: _toString(map['menu_name'] ?? map['name'] ?? '추천 메뉴'),
      category: _toString(map['category'] ?? '일반'),
      moodTags: _toStringList(map['mood_tags'] ?? map['moodTags']),
      situationTags: _toStringList(map['situation_tags'] ?? map['situationTags']),
      budgetMin: _toInt(map['budget_min'] ?? map['budgetMin'] ?? 0),
      budgetMax: _toInt(map['budget_max'] ?? map['budgetMax'] ?? 0),
      spicyLevel: _toString(map['spicy_level'] ?? map['spicyLevel'] ?? '보통'),
      fullness: _toString(map['fullness'] ?? '보통'),
      cookable: (map['cookable'] is bool) ? map['cookable'] : false,
      eatOut: (map['eat_out'] ?? map['eatOut']) is bool ? (map['eat_out'] ?? map['eatOut']) : false,
      recommendText: _toString(map['recommend_text'] ??
          map['recommendText'] ??
          map['reason'] ??
          map['description'] ??
          '오늘 당신에게 딱 맞는 메뉴입니다.'),
      ingredients: _toStringList(map['ingredients']),
      recipeSteps: _toStringList(map['recipe_steps'] ?? map['recipeSteps']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menu_id': menuId,
      'menu_name': menuName,
      'category': category,
      'mood_tags': moodTags,
      'situation_tags': situationTags,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'spicy_level': spicyLevel,
      'fullness': fullness,
      'cookable': cookable,
      'eat_out': eatOut,
      'recommend_text': recommendText,
      'ingredients': ingredients,
      'recipe_steps': recipeSteps,
    };
  }

  static String _toString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final cleanString = value.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleanString) ?? 0;
    }
    return 0;
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
