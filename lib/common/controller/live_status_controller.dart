import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/live_rooms_page_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/firebase_const.dart';

/// Keeps a live map of "who is LIVE right now" so any avatar in the app
/// (feed, reels, stories, profile) can show the blinking red LIVE ring and
/// jump straight into the stream when tapped.
class LiveStatusController extends GetxController {
  static LiveStatusController get to {
    if (Get.isRegistered<LiveStatusController>()) {
      return Get.find<LiveStatusController>();
    }
    return Get.put(LiveStatusController(), permanent: true);
  }

  static const int _staleAfterMs = 60000;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;
  Timer? _pruneTimer;

  /// hostId -> active livestream
  final RxMap<int, Livestream> liveByHost = <int, Livestream>{}.obs;
  final Map<int, Livestream> _all = {};

  @override
  void onInit() {
    super.onInit();
    _listen();
    _pruneTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _publish());
  }

  @override
  void onClose() {
    _listener?.cancel();
    _pruneTimer?.cancel();
    super.onClose();
  }

  void _listen() {
    _listener?.cancel();
    _listener = _db
        .collection(FirebaseConst.liveStreams)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        final stream = Livestream.fromJson(data);
        final hostId = stream.hostId;
        if (hostId == null) continue;
        if (change.type == DocumentChangeType.removed) {
          _all.remove(hostId);
        } else {
          _all[hostId] = stream;
        }
      }
      _publish();
    }, onError: (e) => Loggers.error('LiveStatus listen error: $e'));
  }

  void _publish() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = <int, Livestream>{};
    _all.forEach((hostId, stream) {
      if (stream.isDummyLive == 1) {
        next[hostId] = stream;
        return;
      }
      final heartbeat = stream.lastHeartbeatAt ?? stream.createdAt;
      if (heartbeat == null || now - heartbeat <= _staleAfterMs) {
        next[hostId] = stream;
      }
    });
    if (next.length != liveByHost.length ||
        next.keys.any((k) => !liveByHost.containsKey(k))) {
      liveByHost.assignAll(next);
    }
  }

  bool isLive(int? userId) => userId != null && liveByHost.containsKey(userId);

  Livestream? streamOf(int? userId) =>
      userId == null ? null : liveByHost[userId];

  /// Opens the LIVE of [userId] as an audience member, inside a swipeable
  /// [LiveRoomsPageView] seeded with every other room currently live so the
  /// viewer can swipe straight to another one. Does nothing when the user is
  /// not live, when it is our own stream, or when we are already inside a
  /// LIVE screen.
  Future<void> openLive(int? userId) async {
    final stream = streamOf(userId);
    if (stream == null) return;
    if (userId == SessionManager.instance.getUserID()) return;
    if (LivestreamScreenController.activeRoomIds.isNotEmpty) return;
    await Get.to(
      () => LiveRoomsPageView(
          initialRoom: stream, rooms: liveByHost.values.toList()),
    );
  }
}
