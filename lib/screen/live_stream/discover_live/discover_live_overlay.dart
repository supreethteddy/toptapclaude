import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/live_ring_avatar.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:shortzz/screen/live_stream/discover_live/discover_live_overlay_controller.dart';
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/live_rooms_page_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/battle_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/live_video_player.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/party_battle_view.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';

/// "Discover LIVE" — a partial-height panel that drops down over whatever
/// screen is currently showing (Reels' top-left LIVE icon opens it) rather
/// than a full page navigation, so browsing who's live never leaves the
/// feed. Shows a horizontal avatar row of every currently-live host and, for
/// whichever one is focused, an actually-live compact preview underneath —
/// tapping that preview (or any other avatar first) commits into the full
/// LiveRoomsPageView.
class DiscoverLiveOverlay extends StatelessWidget {
  const DiscoverLiveOverlay({super.key});

  static void show() {
    Get.put(DiscoverLiveOverlayController());
    showGeneralDialog(
      context: Get.context!,
      barrierColor: Colors.black.withValues(alpha: .45),
      barrierDismissible: true,
      barrierLabel: LKey.discoverLive,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const DiscoverLiveOverlay(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(position: slide, child: child),
        );
      },
    ).then((_) {
      if (Get.isRegistered<DiscoverLiveOverlayController>()) {
        Get.delete<DiscoverLiveOverlayController>();
      }
    });
  }

  void _commit(DiscoverLiveOverlayController controller) {
    final commit = controller.prepareCommit();
    if (commit == null) return;
    final (room, rooms) = commit;
    Get.back();
    Get.to(() => LiveRoomsPageView(initialRoom: room, rooms: rooms));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DiscoverLiveOverlayController>();
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24)),
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(context),
                  _avatarRow(context, controller),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _commit(controller),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white54),
                        Obx(() {
                          final room = controller.focusedRoom.value;
                          return room == null
                              ? const SizedBox()
                              : _CompactLivePreview(room: room);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 14, 10, 8),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Get.back();
              Get.to(() => const LiveStreamSearchScreen());
            },
            child: Text(
              LKey.seeAll.tr,
              style: TextStyleCustom.outFitMedium500(
                  color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              LKey.discoverLive.tr,
              textAlign: TextAlign.center,
              style: TextStyleCustom.unboundedSemiBold600(
                  color: Colors.white, fontSize: 15),
            ),
          ),
          InkWell(
            onTap: Get.back,
            child: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _avatarRow(
      BuildContext context, DiscoverLiveOverlayController controller) {
    final firestoreController = Get.find<FirebaseFirestoreController>();
    return SizedBox(
      height: 96,
      child: Obx(() {
        final rooms = controller.rooms;
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: rooms.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _GoLiveTile(onTap: () {
                Get.back();
                Get.to(() => const CreateLiveStreamScreen());
              });
            }
            final room = rooms[index - 1];
            final AppUser? hostUser =
                room.getHostUser(firestoreController.users);
            return Obx(() {
              final isFocused =
                  controller.focusedRoom.value?.roomID == room.roomID;
              return InkWell(
                onTap: () => controller.onAvatarTap(room),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiveRingAvatar(
                        userId: hostUser?.userId,
                        showLabel: false,
                        onLiveTap: () => controller.onAvatarTap(room),
                        child: CustomImage(
                          size: const Size(60, 60),
                          image: hostUser?.profile?.addBaseURL(),
                          fullName: hostUser?.fullname,
                          strokeWidth: isFocused ? 2 : 0,
                          strokeColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 64,
                        child: Text(
                          hostUser?.username ?? '',
                          style: TextStyleCustom.outFitRegular400(
                              fontSize: 11, color: Colors.white),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        );
      }),
    );
  }
}

class _GoLiveTile extends StatelessWidget {
  final VoidCallback onTap;

  const _GoLiveTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 60,
              width: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: StyleRes.themeGradient,
                shape: BoxShape.circle,
              ),
              child: Image.asset(AssetRes.icLive_1,
                  height: 26, width: 26, color: Colors.white),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                LKey.goLive.tr,
                style: TextStyleCustom.outFitRegular400(
                    fontSize: 11, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The focused room's actually-live video, joined and rendered the same way
/// LiveStreamAudienceScreen does (same tagged LivestreamScreenController),
/// just at a fixed compact height with none of the full screen's chrome
/// (top bar, bottom action bar, comments) — those only appear once the
/// viewer commits into LiveRoomsPageView.
class _CompactLivePreview extends StatelessWidget {
  final Livestream room;

  const _CompactLivePreview({required this.room});

  @override
  Widget build(BuildContext context) {
    final roomID = room.roomID;
    if (roomID == null) return const SizedBox();
    final controller = Get.isRegistered<LivestreamScreenController>(tag: roomID)
        ? Get.find<LivestreamScreenController>(tag: roomID)
        : Get.put(LivestreamScreenController(room.obs, false), tag: roomID);

    return SizedBox(
      height: 220,
      width: double.infinity,
      child: IgnorePointer(
        // The preview itself is a tap target for "commit to fullscreen"
        // (handled by the parent InkWell) — ignore taps on the video/user
        // overlays underneath so they don't intercept it.
        child: Obx(() {
          switch (controller.liveData.value.type) {
            case null:
            case LivestreamType.livestream:
              return LivestreamView(
                streamViews: controller.streamViews,
                controller: controller,
              );
            case LivestreamType.battle:
              return controller.liveData.value.opponentRoomId != null
                  ? PartyBattleView(controller: controller)
                  : BattleView(controller: controller, isAudience: true);
            case LivestreamType.dummy:
              return LivestreamVideoPlayer(
                  controller: controller.videoPlayerController);
          }
        }),
      ),
    );
  }
}
