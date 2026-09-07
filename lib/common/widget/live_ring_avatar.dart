import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/live_status_controller.dart';
import 'package:shortzz/utilities/color_res.dart';

/// Wraps any avatar widget and, while [userId] is LIVE, draws a blinking red
/// ring around it plus an optional "LIVE" pill. Tapping the ring opens the
/// stream. Layout size of [child] is unchanged (the ring is painted outside).
class LiveRingAvatar extends StatelessWidget {
  final int? userId;
  final Widget child;
  final bool showLabel;
  final double ringWidth;
  final double ringGap;
  final VoidCallback? onLiveTap;

  const LiveRingAvatar({
    super.key,
    required this.userId,
    required this.child,
    this.showLabel = true,
    this.ringWidth = 2.5,
    this.ringGap = 3,
    this.onLiveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLive = LiveStatusController.to.isLive(userId);
      if (!isLive) return child;
      final inset = -(ringGap + ringWidth);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onLiveTap ?? () => LiveStatusController.to.openLive(userId),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IgnorePointer(child: child),
            Positioned(
              left: inset,
              top: inset,
              right: inset,
              bottom: inset,
              child: IgnorePointer(child: BlinkingLiveRing(width: ringWidth)),
            ),
            if (showLabel)
              const Positioned(
                bottom: -7,
                child: IgnorePointer(child: LiveBadge()),
              ),
          ],
        ),
      );
    });
  }
}

class BlinkingLiveRing extends StatefulWidget {
  final double width;

  const BlinkingLiveRing({super.key, this.width = 2.5});

  @override
  State<BlinkingLiveRing> createState() => _BlinkingLiveRingState();
}

class _BlinkingLiveRingState extends State<BlinkingLiveRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ColorRes.likeRed.withValues(alpha: 0.35 + 0.65 * t),
              width: widget.width,
            ),
            boxShadow: [
              BoxShadow(
                color: ColorRes.likeRed.withValues(alpha: 0.45 * t),
                blurRadius: 6 + 6 * t,
                spreadRadius: 0.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

class LiveBadge extends StatelessWidget {
  final double fontSize;

  const LiveBadge({super.key, this.fontSize = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: ColorRes.likeRed,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          height: 1.2,
        ),
      ),
    );
  }
}
