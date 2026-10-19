import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/battle_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/live_stream_bottom_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/live_video_player.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/party_battle_view.dart';
import 'package:shortzz/config/gifts/premium_gift_animations.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/gift_animation_overlay.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_background_blur_image.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/premium_gift_reveal_overlay.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_like_button.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LivestreamHostScreen extends StatelessWidget {
  final Livestream livestream;
  final Widget? hostPreview;
  final bool isHost;

  const LivestreamHostScreen(
      {super.key,
      this.hostPreview,
      required this.livestream,
      required this.isHost});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
        LivestreamScreenController(livestream.obs, isHost,
            hostPreview: hostPreview),
        tag: livestream.roomID);

    return Scaffold(
      backgroundColor: blackPure(context),
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: false,
        child: Stack(
          children: [
            // Background blur image view
            const LiveStreamBlurBackgroundImage(),

            /// HOST screen
            Obx(
              () {
                final stream = controller.liveData.value;
                if (stream.type == null) {
                  return const Center(child: Text('No One Can live'));
                }
                // Connected to another independently-live host: show the
                // dual-video party view as soon as they're linked, not only
                // once a PK battle actually starts -- connecting must show
                // both videos without auto-starting a battle (the battle
                // chrome inside PartyBattleView stays dormant on its own
                // until battleType leaves INITIATE, see its own gating).
                if (stream.opponentRoomId != null) {
                  final topMargin =
                      EdgeInsets.only(top: controller.topHeaderHeight.value);
                  return PartyBattleView(
                      controller: controller, margin: topMargin);
                }
                switch (stream.type!) {
                  case LivestreamType.livestream:
                    return LivestreamView(
                        streamViews: controller.streamViews,
                        controller: controller);
                  case LivestreamType.battle:
                    // Top margin matches LiveStreamHostTopView's actual
                    // measured height (see topHeaderHeight) instead of a
                    // fixed guess, so the score bar's crown icon never lands
                    // on top of the badges/title rows above it.
                    final topMargin =
                        EdgeInsets.only(top: controller.topHeaderHeight.value);
                    return BattleView(
                        isAudience: false,
                        controller: controller,
                        margin: topMargin);
                  case LivestreamType.dummy:
                    return LivestreamVideoPlayer(
                        controller: controller.videoPlayerController);
                }
              },
            ),

            // Double-tap anywhere to like (TikTok parity): sits above the
            // video. A single-tap version of this used to swallow every
            // plain tap across the whole screen before it ever reached
            // anything underneath -- comment field, per-tile buttons, the
            // grid's own quick-actions menu -- because a lone GestureDetector
            // claims the tap gesture outright regardless of translucent
            // behaviour (that only controls hit-test pass-through, not
            // gesture-arena priority). Double-tap doesn't compete with a
            // plain single tap the same way, so everything below keeps
            // first pick of any ordinary tap; only an actual double-tap
            // still likes.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: (details) => controller.onLikeButtonTap(
                details.localPosition,
                details.localPosition.dx <
                    MediaQuery.sizeOf(context).width / 2,
              ),
              child: const SizedBox.expand(),
            ),

            // Floating heart bursts, anchored at wherever the GestureDetector
            // above was tapped (see LiveStreamLikeButton). Ignoring pointers
            // so it never steals a tap from the controls stacked on top.
            Positioned.fill(
              child: IgnorePointer(
                child: LiveStreamLikeButton(
                  onLikeTap: (p0) {
                    controller.onLikeTap = p0;
                  },
                ),
              ),
            ),

            KeyboardAvoider(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LiveStreamHostTopView(controller: controller),
                  LiveStreamBottomView(controller: controller),
                ],
              ),
            ),

            Obx(() => GiftAnimationOverlay(
                  trigger: controller.eagleGiftAnimationTrigger.value,
                  frameAssets: LivestreamScreenController.eagleGiftFrames,
                )),

            Obx(() {
              final comment = controller.premiumGiftAnimationComment.value;
              final entry = premiumAnimationForGift(comment?.giftId);
              return PremiumGiftRevealOverlay(
                trigger: controller.premiumGiftAnimationTrigger.value,
                videoUrl: entry?.videoUrl ?? '',
                giftName: entry?.name ?? '',
                sender: comment?.senderUser,
              );
            }),
          ],
        ),
      ),
    );
  }
}
