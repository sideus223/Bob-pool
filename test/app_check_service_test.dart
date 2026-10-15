import 'package:bp2/main.dart' as application;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('demo bootstrap never initializes Firebase or App Check', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await application.main();
    await tester.pumpAndSettle();

    expect(Firebase.apps, isEmpty);
    expect(find.text('로컬 데모 · 로그인 없이 체험'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
