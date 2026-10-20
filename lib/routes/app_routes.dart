import 'package:flutter/material.dart';
import '../screens/login_page.dart';
import '../screens/signup_page.dart';
import '../screens/home_page.dart';
import '../screens/random_menu_picker_page.dart';
import '../screens/settings_page.dart';
import '../screens/board_page.dart';
import '../screens/mypage.dart';
import '../screens/recommend_result_page.dart';
import '../screens/board_detail_page.dart';
import '../screens/recipe_page.dart';
import '../screens/post_write_page.dart';
import '../screens/mood_food_manage_page.dart';
import '../screens/favorite_menu_page.dart';
import '../screens/account_settings_page.dart';
import '../screens/my_posts_page.dart';
import '../core/app_config.dart';
import '../screens/connection_required_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String randomMenu = '/random-menu';
  static const String settings = '/settings';
  static const String board = '/board';
  static const String mypage = '/mypage';
  static const String recommendResult = '/recommend-result';
  static const String boardDetail = '/board-detail';
  static const String recipe = '/recipe';
  static const String postWrite = '/post-write';
  static const String moodFoodManage = '/mood-food-manage';
  static const String favoriteMenu = '/favorite-menu';
  static const String accountSettings = '/account-settings';
  static const String myPosts = '/my-posts';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) =>
        AppConfig.demoMode ? const HomePage() : const LoginPage(),
    signup: (context) => AppConfig.demoMode
        ? const ConnectionRequiredPage()
        : const SignUpPage(),
    home: (context) => const HomePage(),
    randomMenu: (context) => const RandomMenuPickerPage(),
    settings: (context) => const SettingsPage(),
    board: (context) =>
        AppConfig.demoMode ? const ConnectionRequiredPage() : const BoardPage(),
    mypage: (context) => const MyPage(),
    boardDetail: (context) => AppConfig.demoMode
        ? const ConnectionRequiredPage()
        : const BoardDetailPage(),
    recipe: (context) => const RecipePage(),
    postWrite: (context) => AppConfig.demoMode
        ? const ConnectionRequiredPage()
        : const PostWritePage(),
    moodFoodManage: (context) => const MoodFoodManagePage(),
    favoriteMenu: (context) => const FavoriteMenuPage(),
    accountSettings: (context) => AppConfig.demoMode
        ? const ConnectionRequiredPage()
        : const AccountSettingsPage(),
    myPosts: (context) => AppConfig.demoMode
        ? const ConnectionRequiredPage()
        : const MyPostsPage(),
  };
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name != recommendResult) return null;
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => const RecommendResultPage(),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}
