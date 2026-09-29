import 'package:get/get.dart';
import 'package:shortzz/common/controller/live_status_controller.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';

/// Backs the "Discover LIVE" overlay (see discover_live_overlay.dart) shown
/// when the viewer taps the LIVE icon on the Reels feed — a horizontal row
/// of every currently-live host plus a compact, actually-live preview of
/// whichever one is focused, without leaving the feed.
class DiscoverLiveOverlayController extends GetxController {
  /// Every currently-live room, read reactively from the same live-updating
  /// map LiveRoomsPageView already uses — no new Firestore query. Exposed as
  /// a plain getter (not a copied RxList) so widgets that read it inside an
  /// Obx subscribe to the real, single underlying RxMap.
  List<Livestream> get rooms => LiveStatusController.to.liveByHost.values.toList();

  final Rx<Livestream?> focusedRoom = Rx<Livestream?>(null);

  /// Set by [commitToFullScreen] right before it navigates into
  /// LiveRoomsPageView, which reuses this same tagged controller (see the
  /// Get.isRegistered guard in LiveStreamAudienceScreen.build()) rather than
  /// rejoining. Without this flag, onClose's own cleanup — which fires
  /// slightly after Get.back(), once the dialog's route actually finishes
  /// closing — would delete the controller out from under the screen that
  /// just started reusing it.
  bool _handedOff = false;

  @override
  void onInit() {
    super.onInit();
    ReelsScreenController.pauseHomeFeed();
    if (rooms.isNotEmpty) {
      focusedRoom.value = rooms.first;
    }
  }

  @override
  void onClose() {
    if (!_handedOff) _releaseFocusedRoom();
    ReelsScreenController.resumeHomeFeed();
    super.onClose();
  }

  void _releaseFocusedRoom() {
    final roomID = focusedRoom.value?.roomID;
    if (roomID == null) return;
    if (Get.isRegistered<LivestreamScreenController>(tag: roomID)) {
      Get.delete<LivestreamScreenController>(tag: roomID, force: true);
    }
  }

  /// Switches the compact preview to [room] — releases the previously
  /// focused room's join first so only ever one extra Zego join is alive at
  /// a time while browsing.
  void onAvatarTap(Livestream room) {
    if (focusedRoom.value?.roomID == room.roomID) return;
    _releaseFocusedRoom();
    focusedRoom.value = room;
  }

  /// The focused room's already-live controller and the full room list, for
  /// the widget to hand off into LiveRoomsPageView. Marks the hand-off so
  /// onClose doesn't tear down the controller the new screen is about to
  /// reuse.
  (Livestream, List<Livestream>)? prepareCommit() {
    final room = focusedRoom.value;
    if (room == null) return null;
    _handedOff = true;
    return (room, rooms);
  }
}
