import 'package:flutter/material.dart';

class BobpoolCooker extends StatelessWidget {
  final Animation<double>? animation;
  final double size;
  const BobpoolCooker({super.key, this.animation, this.size = 240});

  static String frameAsset(int index) =>
      'assets/illustrations/cooker/pose-$index.png';

  Widget _frame(double progress) {
    const keys = [0.0, .26, .34, .42, .50, .62, .72, .82];
    var index = 0;
    for (var i = 1; i < keys.length; i++) {
      if (progress >= keys[i]) index = i;
    }
    final blend = index == 0
        ? 1.0
        : ((progress - keys[index]) / .065).clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Image.asset(frameAsset(index), gaplessPlayback: true),
          if (index > 0 && blend < 1)
            Opacity(
              opacity: 1 - blend,
              child: Image.asset(frameAsset(index - 1), gaplessPlayback: true),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: animation == null
        ? _frame(0)
        : AnimatedBuilder(
            animation: animation!,
            builder: (context, _) => _frame(animation!.value),
          ),
  );
}
