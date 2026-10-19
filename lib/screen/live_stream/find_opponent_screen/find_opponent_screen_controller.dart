import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/firebase_const.dart';

/// The Co-Host candidate list: other creators currently LIVE in their own,
/// independent sessions, not already connected to (or mid-invite with)
/// anyone else. Per the client's binding clarification, Co-host is
/// EXCLUSIVELY this cross-room connection -- there is no in-room co-host
/// concept any more (everyone invited into a host's own room is a Guest),
/// so this screen no longer has an in-room section at all.
class FindOpponentScreenController extends BaseController {
  final LivestreamScreenController myLive;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final firestoreController = Get.find<FirebaseFirestoreController>();

  RxList<Livestream> candidates = <Livestream>[].obs;
  RxSet<int> invitedHostIds = <int>{}.obs;
  StreamSubscription<QuerySnapshot>? _listener;

  FindOpponentScreenController(this.myLive);

  @override
  void onInit() {
    super.onInit();
    isLoading.value = true;
    _listener =
        db.collection(FirebaseConst.liveStreams).snapshots().listen((snapshot) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final myHostId = myLive.liveData.value.hostId;
      candidates.value = snapshot.docs
          .map((doc) => Livestream.fromJson(doc.data()))
          .where((stream) {
        if (stream.hostId == null || stream.hostId == myHostId) return false;
        if (stream.isDummyLive == 1) return false;
        // Already connected to (or mid-connect-invite with) someone else --
        // not available for a new Co-Host connection (one connection, plus
        // optionally one 2v2 teammate link, at a time per host).
        if (stream.opponentRoomId != null) return false;
        if (stream.pendingBattleInviteFromId != null) return false;
        final heartbeat = stream.lastHeartbeatAt ?? stream.createdAt;
        return heartbeat == null || now - heartbeat <= 60000;
      }).toList();
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);
  }

  @override
  void onClose() {
    _listener?.cancel();
    super.onClose();
  }

  Future<void> inviteCoHostConnect(Livestream stream) async {
    if (stream.hostId == null) return;
    invitedHostIds.add(stream.hostId!);
    await myLive.sendCoHostConnectInvite(stream.hostId!);
  }
}
