import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A decorative photo chosen once per process, separate from recommendations.
class HomeHeroImageService {
  static final instance = HomeHeroImageService();
  static const _lastImageKey = 'home_hero_last_image';
  Future<String>? _sessionImage;

  Future<String> get imageForSession => _sessionImage ??= _choose();

  Future<String> _choose() async {
    const fallback = 'assets/images/menus/1.jpg';
    List<String> images;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      images = manifest.listAssets().where((asset) {
        return asset.startsWith('assets/images/menus/') &&
            asset.endsWith('.jpg');
      }).toList()..sort();
    } catch (_) {
      return fallback;
    }
    if (images.isEmpty) return fallback;

    SharedPreferences? preferences;
    String? previous;
    try {
      preferences = await SharedPreferences.getInstance();
      previous = preferences.getString(_lastImageKey);
    } catch (_) {
      // Optional image history must not prevent the home screen from opening.
    }
    final candidates = images.length > 1
        ? images.where((image) => image != previous).toList()
        : images;
    final selected = candidates[Random().nextInt(candidates.length)];
    try {
      await preferences?.setString(_lastImageKey, selected);
    } catch (_) {
      // Keep this session's photo even when saving the previous choice fails.
    }
    return selected;
  }
}
