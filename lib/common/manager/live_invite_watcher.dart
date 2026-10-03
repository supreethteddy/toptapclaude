import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/live_invite_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/live_invite.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/live_stream_audience_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/widget/live_stream_join_sheet.dart';
import 'package:shortzz/utilities/firebase_const.dart';

/// Shows "<host> invited you to join the LIVE as a Co-host / Guest" anywhere
/// in the app, for invites to people who are NOT in the host's room. Modelled
/// on IncomingCallWatcher: one global Firestore listener started after login,
/// de-duplicated by invite id, stale documents ignored, one sheet at a time.
///
/// Accept = reserve a seat on the room doc (transaction, cap-checked), stash
/// the invite for the room controller, then enter the room as a viewer; the
/// controller finishes the promotion once its own user_state doc exists.
class LiveInviteWatcher {
  LiveInviteWatcher._();

  static final LiveInviteWatcher instance = LiveInviteWatcher._();

  /// Room ids with an open LivestreamScreenController. Invites for a room
  /// the user is already inside are handled by the in-room INVITED path, so
  /// the watcher must not double-prompt for them.
  static final Set<String> activeRoomIds = <String>{};

  StreamSubscription<List<LiveInvite>>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _presentedSub;
  Timer? _expiryTimer;
  final Set<String> _handled = <String>{};
  String? _presentedId;
  int? _myId;

  static const _staleAfter = Duration(seconds: 60);

  void start() {
    final myId = SessionManager.instance.getUserID();
    if (myId <= 0) return;
    if (_sub != null && _myId == myId) return;
    stop();
    _myId = myId;
    _sub = LiveInviteService.instance.watchIncoming(myId).listen(
          _onInvites,
          onError: (Object e) =>
              Loggers.error('LiveInviteWatcher listen failed: $e'),
        );
    Loggers.info('LiveInviteWatcher started for user $myId');
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _dismissPresented();
    _handled.clear();
    _myId = null;
  }

  void _onInvites(List<LiveInvite> invites) {
    final now = DateTime.now();
    for (final invite in invites) {
      if (_handled.contains(invite.id)) continue;
      // Ignore replays of old documents when the listener (re)starts, and
      // anything already past its own expiry.
      final created = invite.createdAt;
      if (created != null && now.difference(created) > _staleAfter) {
        _handled.add(invite.id);
        continue;
      }
      if (invite.isExpiredAt(now)) {
        _handled.add(invite.id);
        unawaited(LiveInviteService.instance
            .updateStatus(invite.id, LiveInviteStatus.expired));
        continue;
      }
      if (activeRoomIds.contains(invite.roomId)) {
        // Already in that room: the host's in-room invite path owns this.
        _handled.add(invite.id);
        continue;
      }
      if (_presentedId != null) continue; // one sheet at a time; next pass
      _handled.add(invite.id);
      unawaited(present(invite));
    }
  }

  /// Also used by the FCM tap handler, which re-reads the invite first.
  Future<void> present(LiveInvite invite) async {
    if (_presentedId != null) return;
    _presentedId = invite.id;
    _handled.add(invite.id);

    final host = AppUser(
      userId: invite.hostId,
      username: invite.hostUsername,
      fullname: invite.hostFullname,
      profile: invite.hostProfile,
    );

    // Host cancelled / it expired while the sheet is up -> close it.
    _presentedSub = FirebaseFirestore.instance
        .collection(LiveInviteService.collection)
        .doc(invite.id)
        .snapshots()
        .listen((snap) {
      final status = LiveInviteStatus.fromValue(snap.data()?['status']);
      if (status != null && status != LiveInviteStatus.pending) {
        if (_presentedId == invite.id && (Get.isBottomSheetOpen ?? false)) {
          Get.back();
        }
        if (status == LiveInviteStatus.cancelled) {
          BaseController.share.showSnackBar(LKey.joinCancelledDescription.tr);
        }
      }
    });

    final remaining = invite.expiresAt?.difference(DateTime.now());
    if (remaining != null && remaining > Duration.zero) {
      _expiryTimer = Timer(remaining, () {
        if (_presentedId != invite.id) return;
        if (Get.isBottomSheetOpen ?? false) Get.back();
        unawaited(LiveInviteService.instance
            .updateStatus(invite.id, LiveInviteStatus.expired));
      });
    }

    await Get.bottomSheet(
      LiveStreamJoinSheet(
        hostUser: host,
        myUser: SessionManager.instance.getUser(),
        role: invite.role,
        onJoined: () => unawaited(_accept(invite)),
        onCancel: () => unawaited(LiveInviteService.instance
            .updateStatus(invite.id, LiveInviteStatus.declined)),
      ),
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
    );
    _dismissPresented();
  }

  void _dismissPresented() {
    _presentedSub?.cancel();
    _presentedSub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _presentedId = null;
  }

  int _capFor(LivestreamUserType role) {
    final setting = SessionManager.instance.getSettings();
    return role == LivestreamUserType.coHost
        ? (setting?.maxLiveCohosts ?? 3)
        : (setting?.maxLiveGuests ?? 9);
  }

  Future<void> _accept(LiveInvite invite) async {
    final myId = SessionManager.instance.getUserID();
    final roomRef = FirebaseFirestore.instance
        .collection(FirebaseConst.liveStreams)
        .doc(invite.roomId);
    final arrayKey = invite.role == LivestreamUserType.coHost
        ? FirebaseConst.coHostIds
        : FirebaseConst.guestIds;
    final cap = _capFor(invite.role);

    // Reserve the seat first so two accepters can't both take the last one;
    // publishCoHostStream converts the reservation into membership later.
    String? failure;
    Map<String, dynamic>? roomData;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(roomRef);
        if (!snap.exists) {
          failure = LKey.livestreamHasEnded.tr;
          return;
        }
        roomData = snap.data();
        final members = (roomData?[arrayKey] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();
        final pending =
            (roomData?[FirebaseConst.pendingSeatIds] as List<dynamic>? ??
                    const [])
                .whereType<num>()
                .map((e) => e.toInt())
                .toList();
        if (members.contains(myId) || pending.contains(myId)) return;
        if (members.length + pending.length >= cap) {
          failure = invite.role == LivestreamUserType.coHost
              ? LKey.coHostSeatsFull.tr
              : LKey.guestSeatsFull.tr;
          return;
        }
        tx.update(roomRef, {
          FirebaseConst.pendingSeatIds: FieldValue.arrayUnion([myId]),
        });
      });
    } catch (e) {
      Loggers.error('Accepting live invite failed: $e');
      failure ??= LKey.somethingWentWrong.tr;
    }

    if (failure != null || roomData == null) {
      BaseController.share.showSnackBar(failure ?? LKey.livestreamHasEnded.tr);
      await LiveInviteService.instance.updateStatus(
        invite.id,
        failure == LKey.livestreamHasEnded.tr
            ? LiveInviteStatus.expired
            : LiveInviteStatus.seatsFull,
      );
      return;
    }

    await LiveInviteService.instance
        .updateStatus(invite.id, LiveInviteStatus.accepted);
    LiveInviteService.instance.stashAccepted(invite);

    final stream = Livestream.fromJson(roomData!);
    Get.to(() => LiveStreamAudienceScreen(isHost: false, livestream: stream));
  }
}
