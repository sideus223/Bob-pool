import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_config.dart';
import 'services/auth_service.dart';
import 'services/user_menu_preference_service.dart';
import 'services/firestore_preference_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/home_page.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.demoMode) {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      runApp(
        const MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '서비스 연결을 시작하지 못했어요.\n네트워크 연결과 앱 설정을 확인한 후 다시 실행해 주세요.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }
  }
  UserMenuPreferenceService.scopeProvider = () =>
      AuthService.currentUser?.id ?? 'guest';
  if (!AppConfig.demoMode) {
    UserMenuPreferenceService.store = FirestorePreferenceStore(
      firestore: FirebaseFirestore.instance,
      currentUid: () => AuthService.currentUser?.id,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '밥풀',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // AuthGate를 통해 로그인 상태에 따라 화면 분기
      home: AppConfig.demoMode ? const HomePage() : const AuthGate(),
      routes: AppRoutes.routes,
    );
  }
}
