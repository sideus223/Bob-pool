import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bp2/core/theme/app_theme.dart';
import 'package:bp2/models/board_page_result.dart';
import 'package:bp2/models/post_model.dart';
import 'package:bp2/routes/app_routes.dart';
import 'package:bp2/screens/board_page.dart';
import 'package:bp2/screens/home_page.dart';
import 'package:bp2/screens/mypage.dart';
import 'package:bp2/screens/random_menu_picker_page.dart';
import 'package:bp2/services/local_recommend_service.dart';
import 'package:bp2/services/user_menu_preference_service.dart';
import 'package:bp2/services/visual_preferences.dart';
import 'package:bp2/services/home_hero_image_service.dart';
import 'package:bp2/widgets/menu_summary_card.dart';
import 'package:bp2/widgets/recommendation/bobpool_cooker.dart';
import 'support/phone_preview.dart';

const captureDirectory = String.fromEnvironment('UI_CAPTURE_DIR');
final boundaryKey = GlobalKey();

Widget app(Widget home) => RepaintBoundary(
  key: boundaryKey,
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: home,
    routes: AppRoutes.routes,
    onGenerateRoute: AppRoutes.onGenerateRoute,
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (captureDirectory.isEmpty) return;
  final images = find.byType(Image).evaluate().toList();
  await tester.runAsync(() async {
    await Future.wait(
      images.map(
        (element) => precacheImage((element.widget as Image).image, element),
      ),
    );
  });
  await tester.pump();
  for (final image in tester.widgetList<RawImage>(find.byType(RawImage))) {
    expect(
      image.image,
      isNotNull,
      reason: 'Capture only after image pixels are ready',
    );
  }
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(captureDirectory).create(recursive: true);
    await File(
      '$captureDirectory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    await writePhonePreview(image, '$captureDirectory/$name-phone.png');
    image.dispose();
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserMenuPreferenceService.scopeProvider = () => 'visual-refresh';
  });

  Future<void> prepare(WidgetTester tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await LocalRecommendService.getAllMenus();
      final font = FontLoader('NotoSansKR')
        ..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (var i = 0; i < 8; i++) {
        await rootBundle.load(BobpoolCooker.frameAsset(i));
      }
    });
  }

  testWidgets('checked preference survives recreation and skips animation', (
    tester,
  ) async {
    await prepare(tester);
    await tester.pumpWidget(app(const RandomMenuPickerPage()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    await tester.tap(find.text('애니메이션 건너뛰기'));
    await tester.pumpAndSettle();
    expect(await VisualPreferences.skipAnimation(), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(const RandomMenuPickerPage()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('이 조건으로 추천받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('나를 위한 추천'), findsOneWidget);
    final prefs = await UserMenuPreferenceService.snapshot('무난함');
    expect(
      prefs.history.values.fold<int>(
        0,
        (sum, value) => sum + value.recommendationCount,
      ),
      1,
    );
    await tester.runAsync(
      () => precacheImage(
        AssetImage(
          tester
              .widget<MenuSummaryCard>(find.byType(MenuSummaryCard))
              .menu
              .imageAssetPath,
        ),
        tester.element(find.byType(MenuSummaryCard)),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'result-current');
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving during cooker animation safely cancels presentation', (
    tester,
  ) async {
    await prepare(tester);
    await tester.pumpWidget(app(const RandomMenuPickerPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 조건으로 추천받기'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home profile and board share white theme and mascot avatars', (
    tester,
  ) async {
    await prepare(tester);
    await tester.pumpWidget(app(const RandomMenuPickerPage()));
    await tester.pumpAndSettle();
    await capture(tester, 'recommendation-current');
    await tester.tap(find.text('랜덤 추천'));
    await tester.pumpAndSettle();
    await capture(tester, 'random-current');
    await tester.pumpWidget(app(const HomePage()));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final path = await HomeHeroImageService.instance.imageForSession;
      await precacheImage(
        AssetImage(path),
        tester.element(find.byType(HomePage)),
      );
    });
    await tester.pumpAndSettle();
    await capture(tester, 'home-current');
    await tester.pumpWidget(app(const MyPage()));
    await tester.pumpAndSettle();
    await capture(tester, 'mypage-bobpool-profile');
    final posts = [
      PostModel(
        id: 'preview-1',
        title: '오늘 점심은 김치찌개로 결정!',
        content: '추천받은 메뉴로 든든하게 먹었어요. 다들 오늘 뭐 드셨나요?',
        authorUid: 'preview-a',
        authorNickname: '든든한 밥풀',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        likedBy: const ['p1', 'p2', 'p3'],
        commentCount: 2,
      ),
      PostModel(
        id: 'preview-2',
        title: '혼밥하기 좋은 메뉴 추천해 주세요',
        content: '간단하게 먹을 수 있는 한 끼를 찾고 있어요.',
        authorUid: 'preview-b',
        authorNickname: '한 끼 탐험가',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        likedBy: const ['p1'],
        commentCount: 4,
      ),
      PostModel(
        id: 'preview-3',
        title: '오랜만에 직접 만든 볶음밥',
        content: '냉장고 속 채소와 달걀로 간단하게 만들었어요.',
        authorUid: 'preview-c',
        authorNickname: '집밥 좋아요',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        commentCount: 1,
      ),
    ];
    await tester.pumpWidget(
      app(
        BoardPage(loadPage: (_) async => BoardPageResult(posts, null, false)),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'board-current');
    if (captureDirectory.isNotEmpty) {
      await tester.runAsync(() async {
        await writePhoneOverview(
          captureDirectory,
          'phone-home-recommendation',
          [
            ('home-current', '홈'),
            ('recommendation-current', '맞춤 추천'),
            ('random-current', '랜덤 추천'),
          ],
        );
        if (await File('$captureDirectory/result-current.png').exists()) {
          await writePhoneOverview(captureDirectory, 'phone-result-community', [
            ('result-current', '추천 결과'),
            ('board-current', '게시판'),
            ('mypage-bobpool-profile', '마이페이지'),
          ]);
        }
      });
    }
    expect(find.text('오늘 점심은 김치찌개로 결정!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
