/// Editorial descriptors of the bundled recipe, not allergen or nutrition data.
class FoodTraits {
  static const ingredientValues = [
    '소고기',
    '돼지고기',
    '닭고기',
    '해산물',
    '달걀',
    '콩·두부',
    '채소',
    '유제품',
    '곡물',
  ];
  static const methodValues = ['볶음', '튀김', '구이', '끓임', '찜', '생식', '굽기', '삶기'];
  static const formValues = ['밥', '면', '국물', '빵', '샐러드', '일품', '간식', '기타'];
  static const tasteValues = ['짭짤함', '달콤함', '기름짐', '새콤함'];

  final List<String> mainIngredients;
  final String cookingMethod;
  final String foodForm;
  final List<String> tasteTags;
  const FoodTraits({
    this.mainIngredients = const [],
    this.cookingMethod = '',
    this.foodForm = '',
    this.tasteTags = const [],
  });

  bool get isComplete =>
      mainIngredients.isNotEmpty &&
      cookingMethod.isNotEmpty &&
      foodForm.isNotEmpty;

  factory FoodTraits.fromMap(Object? raw) {
    if (raw == null) return const FoodTraits();
    if (raw is! Map) throw const FormatException('Invalid food traits');
    List<String> tags(String field, List<String> allowed) {
      final value = raw[field];
      if (value is! List ||
          value.isEmpty ||
          value.any((tag) => !allowed.contains(tag)) ||
          value.toSet().length != value.length) {
        throw FormatException('Invalid food trait: $field');
      }
      return List<String>.unmodifiable(value);
    }

    final method = raw['cooking_method'];
    final form = raw['food_form'];
    if (!methodValues.contains(method) || !formValues.contains(form)) {
      throw const FormatException('Invalid food method or form');
    }
    return FoodTraits(
      mainIngredients: tags('main_ingredients', ingredientValues),
      cookingMethod: method as String,
      foodForm: form as String,
      tasteTags: tags('taste_tags', tasteValues),
    );
  }

  Map<String, dynamic> toMap() => {
    'main_ingredients': mainIngredients,
    'cooking_method': cookingMethod,
    'food_form': foodForm,
    'taste_tags': tasteTags,
  };
}
