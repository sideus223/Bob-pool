import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../services/auth_service.dart';
import '../routes/app_routes.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('설정')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('계정 설정'),
          subtitle: AppConfig.demoMode
              ? const Text('Firebase 연결 버전에서 사용')
              : null,
          onTap: () => Navigator.pushNamed(context, AppRoutes.accountSettings),
        ),
        const ListTile(
          leading: Icon(Icons.storage_outlined),
          title: Text('데이터 저장 안내'),
          subtitle: Text(
            AppConfig.demoMode
                ? '데모의 찜·기분별 설정·선택·학습 기록은 이 기기에 저장됩니다. 앱 데이터 삭제 시 함께 삭제됩니다.'
                : '찜·기분별 설정·선택·학습 기록은 로그인한 계정의 서버에 저장됩니다. 다른 기기에서도 같은 계정으로 사용할 수 있습니다.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('밥풀 · 맞춤 추천'),
          subtitle: Text('100개 메뉴 기반의 규칙·피드백 학습 추천'),
        ),
        if (!AppConfig.demoMode)
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () async {
              try {
                await AuthService.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그아웃하지 못했어요. 다시 시도해 주세요.')),
                  );
                }
              }
            },
          ),
      ],
    ),
  );
}
