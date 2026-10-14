import 'package:flutter/material.dart';

class BoardAvatar extends StatelessWidget {
  final String nickname;
  final double radius;
  final double fontSize;
  const BoardAvatar({
    super.key,
    required this.nickname,
    this.radius = 18,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(nickname);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _getInitial(nickname),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '익';
    return trimmed.substring(0, 1).toUpperCase();
  }

  Color _avatarColor(String seed) {
    const colors = [
      Color(0xFFFF8A80),
      Color(0xFF6C8EF5),
      Color(0xFF46C7C7),
      Color(0xFFFFB74D),
      Color(0xFF81C784),
      Color(0xFFBA68C8),
    ];
    final index = seed.isEmpty ? 0 : seed.codeUnitAt(0) % colors.length;
    return colors[index];
  }
}
