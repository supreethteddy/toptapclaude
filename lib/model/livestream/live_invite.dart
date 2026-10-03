import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';

/// Lifecycle of an out-of-room LIVE invitation (`live_invites/{id}`).
enum LiveInviteStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled,
  seatsFull;

  static LiveInviteStatus? fromValue(Object? value) {
    final text = value?.toString();
    for (final status in LiveInviteStatus.values) {
      if (status.name == text) return status;
    }
    return null;
  }
}

/// A host inviting someone who is NOT in their room into a stage role.
///
/// The in-room invite path (host writes `type: INVITED` on the viewer's
/// `user_state` doc) only reaches people whose room listener is already
/// open; this top-level document is what a `LiveInviteWatcher` on the
/// invitee's device listens for from anywhere in the app, and what the FCM
/// push falls back to when the app is backgrounded.
class LiveInvite {
  final String id;
  final int hostId;
  final int inviteeId;
  final String roomId;
  final LivestreamUserType role;
  final String? hostUsername;
  final String? hostFullname;
  final String? hostProfile;
  final LiveInviteStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const LiveInvite({
    required this.id,
    required this.hostId,
    required this.inviteeId,
    required this.roomId,
    required this.role,
    required this.status,
    this.hostUsername,
    this.hostFullname,
    this.hostProfile,
    this.createdAt,
    this.expiresAt,
  });

  bool get isPending => status == LiveInviteStatus.pending;

  bool isExpiredAt(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  static DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  factory LiveInvite.fromJson(String id, Map<String, dynamic> json) {
    return LiveInvite(
      id: id,
      hostId: (json['host_id'] as num?)?.toInt() ?? 0,
      inviteeId: (json['invitee_id'] as num?)?.toInt() ?? 0,
      roomId: json['room_id']?.toString() ?? '',
      role: LivestreamUserType.fromStringOrNull(json['role']) ??
          LivestreamUserType.guest,
      hostUsername: json['host_username'],
      hostFullname: json['host_fullname'],
      hostProfile: json['host_profile'],
      status:
          LiveInviteStatus.fromValue(json['status']) ?? LiveInviteStatus.pending,
      createdAt: _toDate(json['created_at']),
      expiresAt: _toDate(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'invite_id': id,
        'host_id': hostId,
        'invitee_id': inviteeId,
        'room_id': roomId,
        'role': role.value,
        'host_username': hostUsername,
        'host_fullname': hostFullname,
        'host_profile': hostProfile,
        'status': status.name,
        if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
        if (expiresAt != null) 'expires_at': Timestamp.fromDate(expiresAt!),
      };
}
