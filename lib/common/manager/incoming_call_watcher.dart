import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shortzz/common/manager/call_notification_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/call_signaling_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';

/// Watches Firestore for incoming 1:1 calls addressed to the current user and
/// rings them in-app.
///
/// The caller writes a `call_sessions` document (see [CallSignalingService]) and
/// also sends an FCM push. The push can silently fail (backend push not
/// configured, or the callee has no device token), which would otherwise mean
/// the callee is never rung. This watcher is the in-app fallback: while the
/// callee's app is open it detects the pending call session directly and shows
/// the same incoming-call UI the push would have, so calls work device-to-device
/// without depending on backend FCM. It dedupes against push-shown calls by
/// call id, so a call is never rung twice.
class IncomingCallWatcher {
  IncomingCallWatcher._();

  static final IncomingCallWatcher instance = IncomingCallWatcher._();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Set<String> _handled = <String>{};
  int? _myId;

  /// Starts (or restarts for a new user) the incoming-call listener. Safe to
  /// call repeatedly — it no-ops if already watching for the same user.
  void start() {
    final myId = SessionManager.instance.getUserID();
    if (myId <= 0) return;
    if (_sub != null && _myId == myId) return;
    stop();
    _myId = myId;
    _sub = FirebaseFirestore.instance
        .collection('call_sessions')
        .where('callee_id', isEqualTo: myId)
        .where('status', isEqualTo: CallSignalStatus.pending.name)
        .snapshots()
        .listen(_onSnapshot,
            onError: (Object e) =>
                Loggers.error('IncomingCallWatcher listen failed: $e'));
    Loggers.info('IncomingCallWatcher started for user $myId');
  }

  Future<void> _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;
      final data = change.doc.data();
      if (data == null) continue;
      if ((data['status'] as String?) != CallSignalStatus.pending.name) continue;

      final callId = (data['call_id'] as String?) ?? change.doc.id;
      if (_handled.contains(callId)) continue;

      // Ignore stale sessions so we never ring for an old call when the app
      // (re)starts and the listener replays existing documents.
      final createdAt = data['created_at'];
      if (createdAt is Timestamp &&
          DateTime.now().difference(createdAt.toDate()).inSeconds > 60) {
        _handled.add(callId);
        continue;
      }

      // The FCM push may have already shown this call — do not ring twice.
      if (CallNotificationManager.instance.activeIncomingCalls
          .containsKey(callId)) {
        _handled.add(callId);
        continue;
      }

      _handled.add(callId);
      await _ring(callId, data);
    }
  }

  Future<void> _ring(String callId, Map<String, dynamic> data) async {
    try {
      final callerId = (data['caller_id'] as num?)?.toInt();
      if (callerId == null) return;
      final bool isVideo = data['is_video'] == true;

      final User? caller =
          await UserService.instance.fetchUserDetails(userId: callerId);
      if (caller == null) return;

      // Re-check it was not answered/cancelled while we fetched the caller.
      if (CallNotificationManager.instance.activeIncomingCalls
          .containsKey(callId)) {
        return;
      }

      await CallNotificationManager.instance.showIncomingCall(
        callId: callId,
        caller: caller,
        channelId: callId,
        isVideoCall: isVideo,
      );
    } catch (e) {
      Loggers.error('IncomingCallWatcher ring failed for $callId: $e');
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _myId = null;
  }
}
