import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/controller/live_status_controller.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/live_ring_avatar.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/live_rooms_page_view.dart';
import 'package:shortzz/screen/reels_screen/reels_screen.dart'
    show CustomPageViewScrollPhysics;
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';

/// Full-screen "browse who's LIVE" feed, replacing the old half-screen
/// DiscoverLiveOverlay. Reels-style vertical paging over every currently-live
/// room (LiveStatusController.liveByHost — already reactive, no new Firestore
/// listener) — swiping between pages here is a pure, local, read-only UI
/// action: it never creates a LivestreamScreenController, never calls
/// zegoEngine.loginRoom(), and never touches Firestore, so it cannot
/// increment watching_count or fire the "X joined the stream" comment (the
/// old overlay did all of that the moment a room was merely focused — see
/// _CompactLivePreview in discover_live_overlay.dart, now removed). The
/// actual join only happens once a card is tapped and LiveRoomsPageView
/// mounts a real LiveStreamAudienceScreen for that one room.
class LiveDiscoveryFeedScreen extends StatefulWidget {
  const LiveDiscoveryFeedScreen({super.key});

  @override
  State<LiveDiscoveryFeedScreen> createState() =>
      _LiveDiscoveryFeedScreenState();
}

class _LiveDiscoveryFeedScreenState extends State<LiveDiscoveryFeedScreen> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    ReelsScreenController.pauseHomeFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    ReelsScreenController.resumeHomeFeed();
    super.dispose();
  }

  void _enterLive(Livestream room, List<Livestream> rooms) {
    Get.to(() => LiveRoomsPageView(initialRoom: room, rooms: rooms));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final rooms = LiveStatusController.to.liveByHost.values.toList();
        return Stack(
          children: [
            if (rooms.isEmpty)
              const _EmptyState()
            else
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const CustomPageViewScrollPhysics(),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  return _LiveDiscoveryPreviewCard(
                    room: room,
                    onTap: () => _enterLive(room, rooms),
                  );
                },
              ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomBackButton(
                      color: Colors.white,
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(8),
                    ),
                    InkWell(
                      onTap: () => Get.to(() => const LiveStreamSearchScreen()),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.search, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _LiveDiscoveryPreviewCard extends StatelessWidget {
  final Livestream room;
  final VoidCallback onTap;

  const _LiveDiscoveryPreviewCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firestoreController = Get.find<FirebaseFirestoreController>();
    final AppUser? hostUser = room.getHostUser(firestoreController.users);
    final watchingCount = (room.watchingCount ?? 0).clamp(0, 1 << 31);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred host-photo backdrop, same treatment used for the
          // no-video placeholder elsewhere in the LIVE screens, so a
          // preview never looks like a bare black page even though it
          // carries no actual stream video (see the Zego-coupling note
          // in this feature's memory — true video preview would require
          // subscribing to the room, which is exactly the join this
          // screen must not trigger).
          CustomImage(
            size: Size(MediaQuery.sizeOf(context).width,
                MediaQuery.sizeOf(context).height),
            image: hostUser?.profile?.addBaseURL(),
            fullName: hostUser?.fullname,
            radius: 0,
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withValues(alpha: .35)),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiveRingAvatar(
                  userId: hostUser?.userId,
                  onLiveTap: onTap,
                  child: CustomImage(
                    size: const Size(110, 110),
                    image: hostUser?.profile?.addBaseURL(),
                    fullName: hostUser?.fullname,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  hostUser?.username ?? '',
                  style: TextStyleCustom.unboundedSemiBold600(
                      color: Colors.white, fontSize: 17),
                ),
                if ((room.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      room.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyleCustom.outFitRegular400(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 20,
            bottom: 70,
            child: Row(
              children: [
                const LiveBadge(fontSize: 11),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(AssetRes.icAudience,
                          height: 14, width: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        watchingCount.numberFormat,
                        style: TextStyleCustom.outFitMedium500(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Text(
              LKey.tapToJoin.tr,
              textAlign: TextAlign.center,
              style: TextStyleCustom.outFitRegular400(
                  color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_outlined, color: Colors.white38, size: 56),
            const SizedBox(height: 14),
            Text(
              LKey.noOneLiveTitle.tr,
              style: TextStyleCustom.unboundedSemiBold600(
                  color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              LKey.noOneLiveDescription.tr,
              style: TextStyleCustom.outFitLight300(
                  color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
