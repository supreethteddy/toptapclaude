import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/live_ring_avatar.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/live_stream_audience_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen.dart'
    show CustomPageViewScrollPhysics;
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Vertical swipe between live rooms, TikTok-style.
///
/// Only the settled (current) page actually joins its room — a full
/// [LiveStreamAudienceScreen] with its own tagged LivestreamScreenController,
/// Zego login and Firestore listeners. Neighbouring pages render a
/// lightweight static [_LiveRoomPreview] (host avatar/name only, from data
/// LiveStatusController already streams) and only become real once swiped
/// onto — a device only ever actually watches one room's stream at a time,
/// so there is no reason to pay a Zego login for pages the viewer hasn't
/// reached yet.
class LiveRoomsPageView extends StatefulWidget {
  final Livestream initialRoom;
  final List<Livestream> rooms;

  const LiveRoomsPageView(
      {super.key, required this.initialRoom, required this.rooms});

  @override
  State<LiveRoomsPageView> createState() => _LiveRoomsPageViewState();
}

class _LiveRoomsPageViewState extends State<LiveRoomsPageView> {
  late final List<Livestream> _rooms =
      widget.rooms.isEmpty ? [widget.initialRoom] : widget.rooms;
  late int _currentIndex = _initialIndex();
  late final PageController _pageController =
      PageController(initialPage: _currentIndex);

  int _initialIndex() {
    final index = _rooms
        .indexWhere((room) => room.roomID == widget.initialRoom.roomID);
    return index == -1 ? 0 : index;
  }

  /// Only [Get.put] created this room's controller (audience side never
  /// hosts, so it's always safe to delete here) — releasing it the moment a
  /// room stops being the settled page frees its Zego login, Firestore
  /// listeners and wakelock immediately, instead of leaking them for every
  /// room a viewer has swiped past.
  void _releaseRoom(Livestream room) {
    final roomID = room.roomID;
    if (roomID == null) return;
    if (Get.isRegistered<LivestreamScreenController>(tag: roomID)) {
      Get.delete<LivestreamScreenController>(tag: roomID, force: true);
    }
  }

  void _onPageChanged(int index) {
    final previousRoom = _rooms[_currentIndex];
    setState(() => _currentIndex = index);
    if (previousRoom.roomID != _rooms[index].roomID) {
      _releaseRoom(previousRoom);
    }
  }

  @override
  void dispose() {
    _releaseRoom(_rooms[_currentIndex]);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackPure(context),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const CustomPageViewScrollPhysics(),
        itemCount: _rooms.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return index == _currentIndex
              ? LiveStreamAudienceScreen(livestream: room, isHost: false)
              : _LiveRoomPreview(room: room);
        },
      ),
    );
  }
}

class _LiveRoomPreview extends StatelessWidget {
  final Livestream room;

  const _LiveRoomPreview({required this.room});

  @override
  Widget build(BuildContext context) {
    final firestoreController = Get.find<FirebaseFirestoreController>();
    final AppUser? hostUser =
        room.getHostUser(firestoreController.users);

    return Container(
      color: blackPure(context),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveRingAvatar(
            userId: hostUser?.userId,
            showLabel: false,
            child: CustomImage(
              size: const Size(90, 90),
              image: hostUser?.profile?.addBaseURL(),
              fullName: hostUser?.fullname,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hostUser?.username ?? '',
            style: TextStyleCustom.outFitMedium500(
                fontSize: 15, color: whitePure(context)),
          ),
        ],
      ),
    );
  }
}
