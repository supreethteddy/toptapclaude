import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/firebase_const.dart';

/// Lists both (1) co-hosts already on this host's own stage — a direct,
/// pick-one 1v1 invite, since the Match button only auto-starts a match
/// when exactly 2 are eligible — and (2) other creators currently LIVE and
/// not already in a battle, for a cross-room PK Battle invite. A room that
/// already has a co-host (from the multi-guest grid) battles as a 2v2 side
/// automatically — no separate "team up" step needed for the cross-room
/// case.
class FindOpponentScreenController extends BaseController {
  final LivestreamScreenController myLive;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final firestoreController = Get.find<FirebaseFirestoreController>();

  RxList<Livestream> candidates = <Livestream>[].obs;
  RxSet<int> invitedHostIds = <int>{}.obs;
  RxSet<int> invitedCoHostIds = <int>{}.obs;
  StreamSubscription<QuerySnapshot>? _listener;

  FindOpponentScreenController(this.myLive);

  /// On-stage co-hosts (Co-host Mode only — plain Guest Call guests never
  /// become PK players) who are actually publishing right now, excluding
  /// the host. Reactive when read inside an Obx: it touches
  /// [myLive.liveData], [myLive.firestoreController.users] and
  /// [myLive.streamViews].
  List<AppUser> get roomCoHosts {
    final stream = myLive.liveData.value;
    final hostId = stream.hostId;
    final publishingIds = myLive.streamViews
        .map((view) => int.tryParse(view.streamId))
        .whereType<int>()
        .toSet();
    return stream
        .getCoHostUsers(myLive.firestoreController.users)
        .where((user) =>
            user.userId != hostId && publishingIds.contains(user.userId))
        .toList();
  }

  Future<void> inviteRoomCoHost(AppUser user) async {
    final userId = user.userId;
    if (userId == null) return;
    invitedCoHostIds.add(userId);
    await myLive.sendPkMatchInviteTo(userId);
  }

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
