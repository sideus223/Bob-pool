import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({super.key, required this.currentIndex});

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    String routeName;
    switch (index) {
      case 0:
        routeName = AppRoutes.home;
        break;
      case 1:
        routeName = AppRoutes.randomMenu;
        break;
      case 2:
        routeName = AppRoutes.board;
        break;
      case 3:
        routeName = AppRoutes.mypage;
        break;
      default:
        routeName = AppRoutes.home;
    }

    Navigator.pushReplacementNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE6E8ED))),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: const Color(0xFFFD5D69),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: _SelectedTabIcon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: _SelectedTabIcon(Icons.auto_awesome),
            label: '추천',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: _SelectedTabIcon(Icons.chat_bubble),
            label: '게시판',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: _SelectedTabIcon(Icons.person),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }
}

class _SelectedTabIcon extends StatelessWidget {
  final IconData icon;
  const _SelectedTabIcon(this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE8EB),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Icon(icon),
  );
}
