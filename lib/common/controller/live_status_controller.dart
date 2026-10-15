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
  // How much longer a room must keep looking stale, after the first time it
  // was observed stale, before this controller actually deletes it. See
  // _publish()'s comment for why this exists: a single bad reading alone
  // (this device's own clock not yet settled right after a cold boot, a
  // delayed/out-of-order Firestore snapshot, etc.) must never be enough to
  // destroy someone's live session on its own.
  static const int _staleConfirmMs = 20000;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;
  Timer? _pruneTimer;
  final Set<int> _cleaningUp = {};
  final Map<int, int> _firstSeenStaleAt = {};

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
          _firstSeenStaleAt.remove(hostId);
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
        _firstSeenStaleAt.remove(hostId);
        return;
      }
      final heartbeat = stream.lastHeartbeatAt ?? stream.createdAt;
      final isStale = heartbeat != null && now - heartbeat > _staleAfterMs;
      if (!isStale) {
        next[hostId] = stream;
        _firstSeenStaleAt.remove(hostId);
        return;
      }
      // Looks stale right now -- hide it from the UI immediately (matches
      // the behaviour this already had before cleanup was added below), but
      // only actually DELETE it once it's *still* stale on a later,
      // independent check. Confirmed on-device: right after this app cold-
      // boots (e.g. an emulator just started), DateTime.now() can briefly
      // read a bad value before the device clock settles -- one such tick
      // computed every room in the whole collection as hours stale and
      // deleted all of them, including one a host had started seconds
      // earlier. A transient bad reading self-corrects well within
      // _staleConfirmMs; a genuinely abandoned room stays stale on both
      // checks.
      final firstSeen = _firstSeenStaleAt[hostId];
      if (firstSeen == null) {
        _firstSeenStaleAt[hostId] = now;
      } else if (now - firstSeen >= _staleConfirmMs) {
        unawaited(_cleanupStaleRoom(hostId, stream));
      }
    });
    if (next.length != liveByHost.length ||
        next.keys.any((k) => !liveByHost.containsKey(k))) {
      liveByHost.assignAll(next);
    }
  }

  /// Best-effort cleanup for a room whose host hasn't sent a heartbeat in
  /// over _staleAfterMs -- almost always because the host's app was force-
  /// closed, crashed, or lost connectivity without ever reaching the
  /// graceful End Live path, which deletes this same doc itself (see
  /// LivestreamScreenController.deleteStreamOnFirebase). Without this,
  /// nothing deletes the doc unless a regular (non-preview) viewer happens
  /// to stay joined past this same staleness window and runs its own
  /// near-identical self-delete check -- someone only ever browsing the
  /// Discovery Feed (preview-only, never "joins") never triggers that path,
  /// so an abandoned room could otherwise sit marked LIVE forever with a
  /// frozen last frame on-screen. This controller is a permanent singleton
  /// already watching every room's heartbeat for the UI (the LIVE ring,
  /// Discovery Feed, search), which makes it the one place guaranteed to be
  /// running for any client with live-related UI open at all -- far more
  /// reliable than depending on a particular viewer's choice to join.
  /// Mirrors deleteStreamOnFirebase's delete-subcollections-then-doc
  /// pattern; the delete calls are idempotent, so a race between two
  /// clients independently detecting the same stale room is harmless.
  Future<void> _cleanupStaleRoom(int hostId, Livestream stream) async {
    final roomId = stream.roomID;
    if (roomId == null || roomId.isEmpty || _cleaningUp.contains(hostId)) {
      return;
    }
    _cleaningUp.add(hostId);
    try {
      final roomRef = _db.collection(FirebaseConst.liveStreams).doc(roomId);
      final usersSnapshot =
          await roomRef.collection(FirebaseConst.userState).get();
      final commentsSnapshot =
          await roomRef.collection(FirebaseConst.comments).get();
      final refs = <DocumentReference>[
        ...usersSnapshot.docs.map((d) => d.reference),
        ...commentsSnapshot.docs.map((d) => d.reference),
      ];
      const batchSize = 450;
      for (var start = 0; start < refs.length; start += batchSize) {
        final end =
            (start + batchSize < refs.length) ? start + batchSize : refs.length;
        final batch = _db.batch();
        for (final ref in refs.sublist(start, end)) {
          batch.delete(ref);
        }
        await batch.commit();
      }
      await roomRef.delete();
      Loggers.info(
          'LiveStatusController: cleaned up stale room for host $hostId ($roomId)');
    } catch (e) {
      Loggers.error(
          'LiveStatusController: failed to clean up stale room for host $hostId: $e');
    } finally {
      _cleaningUp.remove(hostId);
      _firstSeenStaleAt.remove(hostId);
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
