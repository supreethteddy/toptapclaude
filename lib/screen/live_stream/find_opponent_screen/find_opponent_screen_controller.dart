import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/firebase_const.dart';

/// Lists other creators currently LIVE and not already in a battle, so the
/// host can send a cross-room PK Battle invite. Excludes this host's own
/// room. A room that already has a co-host (from the multi-guest grid)
/// battles as a 2v2 side automatically — no separate "team up" step needed.
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
    _listener = db
        .collection(FirebaseConst.liveStreams)
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final myHostId = myLive.liveData.value.hostId;
      candidates.value = snapshot.docs
          .map((doc) => Livestream.fromJson(doc.data()))
          .where((stream) {
        if (stream.hostId == null || stream.hostId == myHostId) return false;
        if (stream.type == LivestreamType.battle) return false;
        if (stream.isDummyLive == 1) return false;
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

  Future<void> challenge(Livestream stream) async {
    if (stream.hostId == null) return;
    invitedHostIds.add(stream.hostId!);
    await myLive.sendBattleInvite(stream.hostId!);
  }
}
