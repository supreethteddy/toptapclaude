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
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/live_rooms_page_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/battle_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/live_video_player.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/party_battle_view.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:visibility_detector/visibility_detector.dart';

const double _kFeedHeaderHeight = 54;
const double _kFeedFooterHeight = 34;
const double _kFeedMediaAspectRatio = 4 / 5; // width / height
const double _kFeedPostSpacing = 14;

double _feedItemExtent(double screenWidth) {
  final mediaHeight = screenWidth / _kFeedMediaAspectRatio;
  return _kFeedHeaderHeight + mediaHeight + _kFeedFooterHeight + _kFeedPostSpacing;
}

/// Scrollable, Instagram-feed-style "browse who's LIVE" screen, replacing
/// the old half-screen DiscoverLiveOverlay. Every currently-live room
/// (LiveStatusController.liveByHost — already reactive, no new Firestore
/// listener) renders as a bounded post (header, 4:5 preview, caption row)
/// stacked in a normal vertical ListView — not a full-screen swipe-one-at-
/// a-time page. Browsing here is a pure, local, read-only UI action: it
/// never creates a LivestreamScreenController, never calls
/// zegoEngine.loginRoom(), and never touches Firestore, so it cannot
/// increment watching_count or fire the "X joined the stream" comment (the
/// old overlay did all of that the moment a room was merely focused — see
/// _CompactLivePreview in discover_live_overlay.dart, now removed) —
/// except for whichever post is currently ≥80% visible on screen, which
/// gets a real (but still join-free) Zego preview login so its video
/// actually plays; see LiveVideoPreviewCard. The actual join only happens
/// once a post is tapped and LiveRoomsPageView mounts a real
/// LiveStreamAudienceScreen for that one room.
class LiveDiscoveryFeedScreen extends StatefulWidget {
  const LiveDiscoveryFeedScreen({super.key});

  @override
  State<LiveDiscoveryFeedScreen> createState() =>
      _LiveDiscoveryFeedScreenState();
}

class _LiveDiscoveryFeedScreenState extends State<LiveDiscoveryFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _mostVisibleIndex;

  @override
  void initState() {
    super.initState();
    ReelsScreenController.pauseHomeFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    ReelsScreenController.resumeHomeFeed();
    super.dispose();
  }

  /// Avatar-row tap: scrolls the feed so that host's post is in view —
  /// still just browsing, same as scrolling there by hand.
  void _scrollToRoom(int index) {
    final extent = _feedItemExtent(MediaQuery.sizeOf(context).width);
    _scrollController.animateTo(
      index * extent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(() {
          final rooms = LiveStatusController.to.liveByHost.values.toList();
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const CustomBackButton(
                      color: Colors.white,
                      width: 20,
                      height: 20,
                      padding: EdgeInsets.all(8),
                    ),
                    Text(
                      LKey.livestreams.tr.toUpperCase(),
                      style: TextStyleCustom.unboundedSemiBold600(
                          color: Colors.white, fontSize: 14),
                    ),
                    InkWell(
                      onTap: () =>
                          Get.to(() => const LiveStreamSearchScreen()),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.search, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              if (rooms.isNotEmpty)
                _LiveStoryAvatarRow(
                  rooms: rooms,
                  activeIndex: _mostVisibleIndex,
                  onAvatarTap: _scrollToRoom,
                ),
              Expanded(
                child: rooms.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: rooms.length,
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return _LiveFeedPost(
                            key: ValueKey(room.roomID ?? index),
                            room: room,
                            allRooms: rooms,
                            onVisible: () {
                              if (_mostVisibleIndex != index) {
                                setState(() => _mostVisibleIndex = index);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Horizontal "story board" row of every currently-live host, matching the
/// old half-screen overlay's avatar strip the client asked to keep —
/// tapping one just scrolls the feed to that host's post (see
/// _scrollToRoom), it does not itself join anything.
class _LiveStoryAvatarRow extends StatelessWidget {
  final List<Livestream> rooms;
  final int? activeIndex;
  final ValueChanged<int> onAvatarTap;

  const _LiveStoryAvatarRow({
    required this.rooms,
    required this.activeIndex,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreController = Get.find<FirebaseFirestoreController>();
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: rooms.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GoLiveTile(onTap: () {
              Get.off(() => const CreateLiveStreamScreen());
            });
          }
          final roomIndex = index - 1;
          final room = rooms[roomIndex];
          final AppUser? hostUser = room.getHostUser(firestoreController.users);
          final isActive = roomIndex == activeIndex;
          return InkWell(
            onTap: () => onAvatarTap(roomIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CustomImage(
                      size: const Size(56, 56),
                      image: hostUser?.profile?.addBaseURL(),
                      fullName: hostUser?.fullname,
                      strokeWidth: 2,
                      strokeColor: const Color(0xFFFE2C55),
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
        },
      ),
    );
  }
}

/// One post in the Instagram-style feed: host header above a bounded 4:5
/// preview box above a short caption row — the exact opposite of a
/// full-screen Reels card. Tracks its own on-screen visibility (same
/// 80%/mostly-hidden<20% threshold ReelPage uses for autoplay) and only
/// asks for a real video preview — via LiveVideoPreviewCard's isActive —
/// while it is actually the one mostly in view, so at most one room is
/// ever logged into Zego while scrolling this feed.
class _LiveFeedPost extends StatefulWidget {
  final Livestream room;
  final List<Livestream> allRooms;
  final VoidCallback onVisible;

  const _LiveFeedPost({
    super.key,
    required this.room,
    required this.allRooms,
    required this.onVisible,
  });

  @override
  State<_LiveFeedPost> createState() => _LiveFeedPostState();
}

class _LiveFeedPostState extends State<_LiveFeedPost> {
  bool _isVisible = false;

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visibilityPercent = info.visibleFraction * 100;
    if (visibilityPercent >= 80) {
      if (!_isVisible) {
        setState(() => _isVisible = true);
        widget.onVisible();
      }
    } else if (visibilityPercent < 20) {
      if (_isVisible) setState(() => _isVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreController = Get.find<FirebaseFirestoreController>();
    final AppUser? hostUser =
        widget.room.getHostUser(firestoreController.users);
    final description = (widget.room.description ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: _kFeedPostSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _kFeedHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  CustomImage(
                    size: const Size(36, 36),
                    image: hostUser?.profile?.addBaseURL(),
                    fullName: hostUser?.fullname,
                    strokeWidth: 1.5,
                    strokeColor: const Color(0xFFFE2C55),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hostUser?.username ?? '',
                      style: TextStyleCustom.outFitMedium500(
                          color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const LiveBadge(fontSize: 10),
                ],
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: _kFeedMediaAspectRatio,
            child: VisibilityDetector(
              key: Key('live_feed_post_${widget.room.roomID}'),
              onVisibilityChanged: _handleVisibilityChanged,
              child: LiveVideoPreviewCard(
                room: widget.room,
                isActive: _isVisible,
                allRooms: widget.allRooms,
              ),
            ),
          ),
          SizedBox(
            height: _kFeedFooterHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: description.isEmpty
                  ? const SizedBox()
                  : Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyleCustom.outFitRegular400(
                          color: Colors.white54, fontSize: 12),
                    ),
            ),
          ),
        ],
      ),
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
              height: 56,
              width: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: StyleRes.themeGradient,
                shape: BoxShape.circle,
              ),
              child: Image.asset(AssetRes.icLive_1,
                  height: 24, width: 24, color: Colors.white),
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

/// Full-bleed, 9:16 "preview card" for one LIVE room — public (not private
/// to this file) because LiveStreamSearchScreen's own vertical feed reuses
/// it too, instead of its old short fixed-height grid cards. This is the
/// photo-only fallback (host avatar on a blurred backdrop, no real video) —
/// used for every page that isn't currently on-screen; the active page in
/// LiveDiscoveryFeedScreen renders [LiveVideoPreviewCard] instead, which
/// shows the actual live stream.
class LiveDiscoveryPreviewCard extends StatelessWidget {
  final Livestream room;
  final VoidCallback onTap;

  const LiveDiscoveryPreviewCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreController = Get.find<FirebaseFirestoreController>();
    final AppUser? hostUser = room.getHostUser(firestoreController.users);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          // Blurred host-photo backdrop so a not-yet-active preview never
          // looks like a bare black page while it has no video playing.
          CustomImage(
            size: Size(constraints.maxWidth, constraints.maxHeight),
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
          _LivePreviewBadgeOverlay(watchingCount: room.watchingCount ?? 0),
        ],
        ),
      ),
    );
  }
}

/// LIVE badge + viewer count pill + "Tap to join" hint, bottom-anchored —
/// shared between the photo-only [LiveDiscoveryPreviewCard] and the real
/// video [LiveVideoPreviewCard] so both look identical aside from what's
/// playing behind them.
class _LivePreviewBadgeOverlay extends StatelessWidget {
  final int watchingCount;

  const _LivePreviewBadgeOverlay({required this.watchingCount});

  @override
  Widget build(BuildContext context) {
    final count = watchingCount.clamp(0, 1 << 31);
    return Stack(
      children: [
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
                  border: Border.all(color: Colors.white.withValues(alpha: .3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(AssetRes.icAudience,
                        height: 14, width: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      count.numberFormat,
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
    );
  }
}

/// One page of the vertical LIVE-browsing feed. Shows the real video (via a
/// preview-only LivestreamScreenController — see
/// LivestreamScreenController.isPreviewOnly) only while [isActive] (this is
/// the on-screen/current page); every other page falls back to the
/// lightweight, Zego-free [LiveDiscoveryPreviewCard] so only one room is
/// ever actually logged into Zego at a time while browsing. Tapping it
/// upgrades the preview into a real join (no second Zego login — it's
/// already connected) and hands off into the full-screen LiveRoomsPageView.
class LiveVideoPreviewCard extends StatefulWidget {
  final Livestream room;
  final bool isActive;
  final List<Livestream> allRooms;

  const LiveVideoPreviewCard({
    super.key,
    required this.room,
    required this.isActive,
    required this.allRooms,
  });

  @override
  State<LiveVideoPreviewCard> createState() => _LiveVideoPreviewCardState();
}

class _LiveVideoPreviewCardState extends State<LiveVideoPreviewCard> {
  LivestreamScreenController? _controller;
  bool _handedOff = false;

  String? get _roomID => widget.room.roomID;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _attach();
  }

  @override
  void didUpdateWidget(covariant LiveVideoPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _attach();
    } else if (!widget.isActive && oldWidget.isActive) {
      _detach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    final roomID = _roomID;
    if (roomID == null) return;
    // The explicit <LivestreamScreenController> type argument on Get.put
    // below is load-bearing, not stylistic: this call sits inside a ternary
    // whose other branch (Get.find<LivestreamScreenController>) and whose
    // assignment target (_controller, typed LivestreamScreenController?)
    // both feed a nullable context type back into Dart's generic inference
    // for the untyped Get.put(...) call — which then infers its type
    // argument as LivestreamScreenController? instead of
    // LivestreamScreenController. GetX keys its registry by
    // `type.toString() + tag` (get_instance.dart), so that one extra "?"
    // silently registers this controller under a completely different key
    // than every Get.isRegistered/Get.find<LivestreamScreenController>(tag:
    // ...) call elsewhere (_enterLive below, LiveStreamAudienceScreen,
    // LiveRoomsPageView, the gift/members/battle sheets) ever looks up —
    // they report "not registered" despite the instance sitting right there
    // in memory, never disposed. _enterLive()'s real join then logs into
    // the same Zego room a second time, which Zego rejects as a duplicate
    // login (errorCode 1002001), and the viewer never actually joins.
    // permanent: true is kept as real defense-in-depth: this is the one
    // controller in the codebase that must survive the Get.to() push into
    // LiveRoomsPageView below (tapping upgrades it in place and hands it
    // off rather than creating a second one), and we already delete it
    // explicitly ourselves (force: true) the moment it's genuinely done
    // with — see _detach() below and LiveRoomsPageView._releaseRoom() — so
    // nothing leaks.
    _controller = Get.isRegistered<LivestreamScreenController>(tag: roomID)
        ? Get.find<LivestreamScreenController>(tag: roomID)
        : Get.put<LivestreamScreenController>(
            LivestreamScreenController(widget.room.obs, false,
                isPreviewOnly: true),
            tag: roomID,
            permanent: true,
          );
  }

  /// Releases the preview's Zego login the moment this page scrolls off
  /// screen or this widget goes away — unless _enterLive already handed the
  /// same tagged controller off to LiveRoomsPageView, which now owns its
  /// lifecycle instead.
  void _detach() {
    if (_handedOff) return;
    final roomID = _roomID;
    _controller = null;
    if (roomID == null) return;
    if (Get.isRegistered<LivestreamScreenController>(tag: roomID)) {
      Get.delete<LivestreamScreenController>(tag: roomID, force: true);
    }
  }

  Future<void> _enterLive() async {
    final roomID = _roomID;
    if (roomID == null) return;
    final controller = _controller ??
        (Get.isRegistered<LivestreamScreenController>(tag: roomID)
            ? Get.find<LivestreamScreenController>(tag: roomID)
            : null);
    if (controller != null) {
      _handedOff = true;
      await controller.upgradeFromPreviewToJoined();
    }
    Get.to(() =>
        LiveRoomsPageView(initialRoom: widget.room, rooms: widget.allRooms));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!widget.isActive || controller == null) {
      return LiveDiscoveryPreviewCard(room: widget.room, onTap: _enterLive);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enterLive,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
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
          IgnorePointer(
            child: Obx(() => _LivePreviewBadgeOverlay(
                watchingCount: controller.liveData.value.watchingCount ?? 0)),
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
