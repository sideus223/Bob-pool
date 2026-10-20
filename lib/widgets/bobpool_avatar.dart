import 'package:flutter/material.dart';

class BobpoolAvatar extends StatelessWidget {
  final double radius;
  final String? semanticLabel;
  const BobpoolAvatar({super.key, this.radius = 28, this.semanticLabel});

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? '밥풀이 기본 프로필',
    image: true,
    child: CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFEEF0),
      child: Padding(
        padding: EdgeInsets.all(radius * .2),
        child: Image.asset(
          'assets/illustrations/bobpool-avatar.png',
          excludeFromSemantics: true,
        ),
      ),
    ),
  );
}
