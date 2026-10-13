import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/widget/livestream_audience_top_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/battle_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/live_stream_bottom_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/live_video_player.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/party_battle_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/battle_start_countdown_overlay.dart';
import 'package:shortzz/config/gifts/premium_gift_animations.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/gift_animation_overlay.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_background_blur_image.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/premium_gift_reveal_overlay.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_like_button.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveStreamAudienceScreen extends StatelessWidget {
  final Livestream livestream;
  final bool isHost;

  const LiveStreamAudienceScreen(
      {super.key, required this.livestream, required this.isHost});

  @override
  Widget build(BuildContext context) {
    // Explicit <LivestreamScreenController> type argument on Get.put: see
    // the long comment on LiveVideoPreviewCard._attach() in
    // live_discovery_feed_screen.dart — without it, this ternary's downward
    // context can make Dart infer the type argument as
    // LivestreamScreenController? and silently register under a different
    // GetX key than every other Get.find/isRegistered<LivestreamScreenController>
    // call site in the app looks up.
    final controller = Get.isRegistered<LivestreamScreenController>(
            tag: livestream.roomID)
        ? Get.find<LivestreamScreenController>(tag: livestream.roomID)
        : Get.put<LivestreamScreenController>(
            LivestreamScreenController(livestream.obs, isHost),
            tag: livestream.roomID,
          );

    return Scaffold(
      backgroundColor: blackPure(context),
      resizeToAvoidBottomInset: false,
      body: Obx(
        () => PopScope(
          canPop: controller.canPopStreamRoute.value,
          child: Stack(
            children: [
              const LiveStreamBlurBackgroundImage(),

              /// Live StreamView
              Obx(() {
                switch (controller.liveData.value.type) {
                  case null:
                  case LivestreamType.livestream:
                    return LivestreamView(
                      streamViews: controller.streamViews,
                      controller: controller,
                    );
                  case LivestreamType.battle:
                    // Top margin matches LiveStreamAudienceTopView's actual
                    // measured height (see topHeaderHeight) instead of a
                    // fixed guess, so the score bar's crown icon never lands
                    // on top of the badges/title rows above it.
                    final topMargin =
                        EdgeInsets.only(top: controller.topHeaderHeight.value);
                    return controller.liveData.value.opponentRoomId != null
                        ? PartyBattleView(
                            controller: controller,
                            margin: topMargin,
                          )
                        : BattleView(
                            isAudience: true,
                            controller: controller,
                            margin: topMargin,
                          );
                  case LivestreamType.dummy:
                    return LivestreamVideoPlayer(
                        controller: controller.videoPlayerController);
                }
              }),

              // Tap anywhere to like (TikTok parity): sits above the video
              // but below the interactive controls below, which still get
              // first pick of any tap that lands on them.
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (details) => controller.onLikeButtonTap(
                  details.localPosition,
                  details.localPosition.dx <
                      MediaQuery.sizeOf(context).width / 2,
                ),
                child: const SizedBox.expand(),
              ),

              // Floating heart bursts, anchored at wherever the
              // GestureDetector above was tapped (see LiveStreamLikeButton).
              // Ignoring pointers so it never steals a tap from the controls
              // stacked on top.
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
                    LiveStreamAudienceTopView(
                        isAudience: true, controller: controller),
                    LiveStreamBottomView(
                        isAudience: true, controller: controller),
                  ],
                ),
              ),

              Obx(
                () {
                  Livestream stream = controller.liveData.value;
                  // Cross-room battles only — a same-room PK Match
                  // (opponentRoomId null) starts the moment the invite is
                  // accepted, no countdown (client spec).
                  bool isBattle = stream.battleType == BattleType.waiting &&
                      stream.opponentRoomId != null;
                  if (isBattle) {
                    return BattleStartCountdownOverlay(
                        isHost: isHost, stream: stream);
                  }
                  return const SizedBox();
                },
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
      ),
    );
  }
}
