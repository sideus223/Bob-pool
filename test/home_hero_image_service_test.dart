import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/services/home_hero_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'home photo stays stable for the session and exists in bundled assets',
    () async {
      final service = HomeHeroImageService();
      final first = await service.imageForSession;
      final second = await service.imageForSession;
      expect(second, first);
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(manifest.listAssets(), contains(first));
    },
  );

  test('a new app session does not repeat the previous launch photo', () async {
    final firstSession = await HomeHeroImageService().imageForSession;
    final nextSession = await HomeHeroImageService().imageForSession;
    expect(nextSession, isNot(firstSession));
  });
}
