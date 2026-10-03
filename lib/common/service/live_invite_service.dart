import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/live_invite.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';

/// Firestore signalling for inviting someone who is NOT in the host's room
/// (Friends / Recommended tab). Mirrors CallSignalingService: the document
/// is the source of truth, the invitee's LiveInviteWatcher reacts to it, and
/// the FCM push is only a nudge for backgrounded apps.
///
/// Both queries used here are equality-only (`invitee_id == me && status ==
/// pending`, `host_id == x && room_id == y`), so no composite index is needed.
class LiveInviteService {
  LiveInviteService._();

  static final LiveInviteService instance = LiveInviteService._();
  static const collection = 'live_invites';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(collection);

  /// The invite the local user just accepted, handed to the room controller
  /// so it can promote them once their user_state doc exists. Keyed by room
  /// so a stale stash for another room is never consumed by mistake.
  LiveInvite? _acceptedInvite;

  void stashAccepted(LiveInvite invite) => _acceptedInvite = invite;

  LiveInvite? takeAcceptedFor(String roomId) {
    final invite = _acceptedInvite;
    if (invite == null || invite.roomId != roomId) return null;
    _acceptedInvite = null;
    return invite;
  }

  Future<LiveInvite> createInvite({
    required AppUser host,
    required String roomId,
    required int inviteeId,
    required LivestreamUserType role,
    required Duration expiry,
  }) async {
    final now = DateTime.now();
    final id = '${host.userId}_${inviteeId}_${now.millisecondsSinceEpoch}';
    final invite = LiveInvite(
      id: id,
      hostId: host.userId ?? 0,
      inviteeId: inviteeId,
      roomId: roomId,
      role: role,
      hostUsername: host.username,
      hostFullname: host.fullname,
      hostProfile: host.profile,
      status: LiveInviteStatus.pending,
      createdAt: now,
      expiresAt: now.add(expiry),
    );
    final data = invite.toJson()
      ..['created_at'] = FieldValue.serverTimestamp()
      ..['updated_at'] = FieldValue.serverTimestamp();
    await _col.doc(id).set(data);
    return invite;
  }

  Future<void> updateStatus(
    String inviteId,
    LiveInviteStatus status, {
    String? reason,
  }) async {
    if (inviteId.trim().isEmpty) return;
    try {
      await _col.doc(inviteId).set({
        'status': status.name,
        if (reason != null) 'reason': reason,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      Loggers.error('Live invite status update failed: $e');
      rethrow;
    }
  }

  Future<LiveInvite?> fetch(String inviteId) async {
    final snap = await _col.doc(inviteId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return LiveInvite.fromJson(snap.id, data);
  }

  /// Pending invites addressed to [userId] — what the watcher listens to.
  Stream<List<LiveInvite>> watchIncoming(int userId) => _col
      .where('invitee_id', isEqualTo: userId)
      .where('status', isEqualTo: LiveInviteStatus.pending.name)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => LiveInvite.fromJson(d.id, d.data()))
          .toList(growable: false));

  /// Every invite this host sent for this room, any status — drives the
  /// Invited tab's "Invited… / Declined / Seats full" button states.
  Stream<List<LiveInvite>> watchOutgoing(int hostId, String roomId) => _col
      .where('host_id', isEqualTo: hostId)
      .where('room_id', isEqualTo: roomId)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => LiveInvite.fromJson(d.id, d.data()))
          .toList(growable: false));

  /// Host ended the LIVE (or left): nobody should still be able to accept.
  Future<void> cancelAllPending(int hostId, String roomId) async {
    try {
      final snap = await _col
          .where('host_id', isEqualTo: hostId)
          .where('room_id', isEqualTo: roomId)
          .where('status', isEqualTo: LiveInviteStatus.pending.name)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.set(doc.reference, {
          'status': LiveInviteStatus.cancelled.name,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      Loggers.error('Cancelling pending live invites failed: $e');
    }
  }
}
