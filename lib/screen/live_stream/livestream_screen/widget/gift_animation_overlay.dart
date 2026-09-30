import 'package:flutter/material.dart';

/// Full-screen flipbook player for bundled "epic gift" animations. There is
/// no video/SVGA/Lottie pipeline for gifts anywhere in this app — gifts are
/// otherwise just a static image in a toast (see SendGiftDialog) — so this
/// plays a pre-extracted PNG-with-real-alpha frame sequence instead of a
/// video file. That sequence was produced by keying out a fake, baked-in
/// checkerboard "transparency" pattern from a source MP4 that never had a
/// real alpha channel; the source's rain/lightning frames blend that
/// checkerboard into a semi-transparent mist layer, so a few busy frames
/// keep a faint checker artifact — accepted as good-enough rather than
/// re-authoring the source asset.
///
/// [trigger] is any value that changes (e.g. an incrementing int) each time
/// the animation should (re)play; this widget diffs it via [didUpdateWidget]
/// rather than exposing a play() method, since it's meant to be driven by an
/// Obx/ValueListenableBuilder-style rebuild from shared, Firestore-synced
/// state (every viewer in the room sees the same trigger value change at
/// the same time), not a local one-off controller call.
class GiftAnimationOverlay extends StatefulWidget {
  final Object? trigger;
  final List<String> frameAssets;
  final Duration frameDuration;

  const GiftAnimationOverlay({
    super.key,
    required this.trigger,
    required this.frameAssets,
    this.frameDuration = const Duration(milliseconds: 100),
  });

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay> {
  int _frameIndex = -1;
  Ticker? _ticker;

  @override
  void didUpdateWidget(covariant GiftAnimationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger != null) {
      _play();
    }
  }

  void _play() {
    _ticker?.cancel();
    setState(() => _frameIndex = 0);
    _ticker = Ticker(widget.frameDuration, widget.frameAssets.length, (i) {
      if (!mounted) return;
      setState(() => _frameIndex = i);
      if (i == widget.frameAssets.length - 1) {
        Future.delayed(widget.frameDuration, () {
          if (mounted) setState(() => _frameIndex = -1);
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_frameIndex < 0 || widget.frameAssets.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Positioned.fill(
        child: Image.asset(
          widget.frameAssets[_frameIndex],
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

/// Minimal frame-stepping timer — deliberately not `AnimationController`
/// (which needs a `TickerProvider`/`vsync` wired through the call site) since
/// this only ever steps through a fixed frame list at a fixed interval.
class Ticker {
  Ticker(Duration interval, int frameCount, void Function(int frame) onTick) {
    _run(interval, frameCount, onTick);
  }

  bool _cancelled = false;

  Future<void> _run(
      Duration interval, int frameCount, void Function(int) onTick) async {
    for (var i = 0; i < frameCount && !_cancelled; i++) {
      onTick(i);
      await Future.delayed(interval);
    }
  }

  void cancel() => _cancelled = true;
}
