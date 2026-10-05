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
import 'package:shortzz/screen/live_stream/livestream_screen/widget/battle_start_countdown_overlay.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/gift_animation_overlay.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_background_blur_image.dart';
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
                switch (controller.liveData.value.type) {
                  case null:
                    return const Center(child: Text('No One Can live'));
                  case LivestreamType.livestream:
                    return LivestreamView(
                        streamViews: controller.streamViews,
                        controller: controller);
                  case LivestreamType.battle:
                    return controller.liveData.value.opponentRoomId != null
                        ? PartyBattleView(
                            controller: controller,
                            margin: const EdgeInsets.only(top: 60))
                        : BattleView(
                            isAudience: false,
                            controller: controller,
                            margin: const EdgeInsets.only(top: 60));
                  case LivestreamType.dummy:
                    return LivestreamVideoPlayer(
                        controller: controller.videoPlayerController);
                }
              },
            ),

            // Tap anywhere to like (TikTok parity): sits above the video but
            // below the interactive controls below, which still get first
            // pick of any tap that lands on them.
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) => controller.onLikeButtonTap(
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

            Obx(
              () {
                Livestream stream = controller.liveData.value;
                // Cross-room battles only — a same-room PK Match
                // (opponentRoomId null) starts the moment the invite is
                // accepted, no countdown (client spec).
                bool isBattleWaiting = stream.battleType == BattleType.waiting &&
                    stream.opponentRoomId != null;
                if (isBattleWaiting) {
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
          ],
        ),
      ),
    );
  }
}
