import 'food_traits.dart';

/// Append/change keys only with a model version change. No hash collisions.
class LearningFeatureSchema {
  static const version = 2;
  static const dimension = 146;
  static const categories = [
    '한식',
    '분식',
    '일식',
    '중식',
    '양식',
    '면요리',
    '간편식',
    '치킨',
    '아시안',
    '건강식',
    '패스트푸드',
    '기타',
  ];
  static const moods = ['기분좋음', '무난함', '우울함', '피곤함', '스트레스', '설렘'];
  static const situations = ['혼밥', '친구랑', '데이트', '빨리먹기', '가볍게', '든든하게'];
  static final List<String> keys = List.unmodifiable([
    for (final value in categories) 'category:$value',
    for (final value in FoodTraits.ingredientValues) 'ingredient:$value',
    for (final value in FoodTraits.methodValues) 'method:$value',
    for (final value in FoodTraits.formValues) 'form:$value',
    for (final value in FoodTraits.tasteValues) 'taste:$value',
    for (final value in ['순함', '보통', '매움']) 'spice:$value',
    for (final value in ['낮음', '보통', '높음']) 'fullness:$value',
    'cookable',
    'eatOut',
    'price',
    for (final mood in moods)
      for (final form in FoodTraits.formValues) 'mood:$mood/form:$form',
    for (final scene in situations)
      for (final form in FoodTraits.formValues) 'scene:$scene/form:$form',
  ]);
  static final Map<String, int> index = Map.unmodifiable({
    for (var i = 0; i < keys.length; i++) keys[i]: i,
  });
}
