import 'package:shared_preferences/shared_preferences.dart';

/// Presentation preferences never change recommendation or feedback signals.
class VisualPreferences {
  static const skipAnimationKey = 'visual.skip_recommendation_animation';

  static Future<bool> skipAnimation() async =>
      (await SharedPreferences.getInstance()).getBool(skipAnimationKey) ??
      false;

  static Future<void> setSkipAnimation(bool value) async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      skipAnimationKey,
      value,
    );
    if (!saved) throw StateError('애니메이션 설정을 저장하지 못했어요.');
  }
}
