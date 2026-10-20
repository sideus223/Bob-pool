import 'package:flutter/material.dart';
import '../bobpool_avatar.dart';

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
    return BobpoolAvatar(radius: radius, semanticLabel: '$nickname님의 기본 프로필');
  }
}
