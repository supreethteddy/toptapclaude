import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:video_player/video_player.dart';

/// Full-screen cinematic reveal for a premium gift (see
/// `config/gifts/premium_gift_animations.dart`): a sender card up top —
/// avatar, name, "sent [Gift Name]" — then the gift's video filling the
/// rest of the screen below it, matching the client's TikTok reference
/// (host video/chrome stays visible above the card; this plays below it,
/// not as a hard full-screen takeover). Unlike [GiftAnimationOverlay]
/// (a bundled PNG flipbook for exactly one gift), this plays an arbitrary
/// network video and works for any gift in the premium catalogue.
///
/// [trigger] is any value that changes each time the animation should
/// (re)play, same contract as [GiftAnimationOverlay] — driven by a shared,
/// Firestore-synced counter so every viewer in the room sees it at once.
class PremiumGiftRevealOverlay extends StatefulWidget {
  final Object? trigger;
  final String videoUrl;
  final String giftName;
  final AppUser? sender;

  const PremiumGiftRevealOverlay({
    super.key,
    required this.trigger,
    required this.videoUrl,
    required this.giftName,
    required this.sender,
  });

  @override
  State<PremiumGiftRevealOverlay> createState() =>
      _PremiumGiftRevealOverlayState();
}

class _PremiumGiftRevealOverlayState extends State<PremiumGiftRevealOverlay> {
  VideoPlayerController? _controller;
  bool _visible = false;

  @override
  void didUpdateWidget(covariant PremiumGiftRevealOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        widget.trigger != null &&
        widget.videoUrl.isNotEmpty) {
      _play();
    }
  }

  Future<void> _play() async {
    final previous = _controller;
    _controller = null;
    previous?.removeListener(_onTick);
    await previous?.dispose();
    final controller = widget.videoUrl.startsWith('file://')
        ? VideoPlayerController.file(File(Uri.parse(widget.videoUrl).path))
        : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      // Bad/unreachable URL — fail silently, same as a missing asset would.
      return;
    }
    if (!mounted) return;
    setState(() => _visible = true);
    await controller.play();
    controller.addListener(_onTick);
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.isInitialized &&
        !value.isPlaying &&
        value.position >= value.duration) {
      _finish();
    }
  }

  // Disposes the finished controller immediately instead of just hiding it —
  // otherwise it sits alive (holding a native player/texture) until the next
  // gift replaces it or this widget itself is torn down.
  void _finish() {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onTick);
    controller?.dispose();
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_visible || controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Positioned.fill(
        child: Column(
          children: [
            const SizedBox(height: 150),
            _SenderCard(sender: widget.sender, giftName: widget.giftName),
            Expanded(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SenderCard extends StatelessWidget {
  final AppUser? sender;
  final String giftName;

  const _SenderCard({required this.sender, required this.giftName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          CustomImage(
            size: const Size(36, 36),
            image: sender?.profile?.addBaseURL(),
            fullName: sender?.fullname,
            strokeColor: ColorRes.likeRed,
            strokeWidth: 2,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FullNameWithBlueTick(
                  username: sender?.username,
                  isVerify: sender?.isVerify,
                  fontSize: 14,
                  iconSize: 16,
                  fontColor: Colors.white,
                ),
                Text(
                  'sent $giftName',
                  style: TextStyleCustom.outFitLight300(
                      color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
