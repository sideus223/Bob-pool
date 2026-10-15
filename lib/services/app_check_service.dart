import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../core/app_config.dart';

class AppCheckService {
  /// Debug attestation is opt-in and cannot be enabled in profile/release builds.
  static const useDebugProvider =
      kDebugMode && bool.fromEnvironment('APP_CHECK_DEBUG');

  static Future<void> activate() async {
    if (AppConfig.demoMode) return;

    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugProvider
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }
}
