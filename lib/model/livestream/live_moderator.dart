/// One user's Moderator grant for a single LIVE session (client spec Module
/// 14.1 — "Permissions apply only to the LIVE session for which the
/// Moderator is authorized"). Lives at `livestreams/{roomID}/moderators/
/// {userId}`, distinct from the retired permanent app_users-level list.
///
/// Named `LiveModerator`, not `Moderator`, to avoid colliding with the
/// unrelated global platform-moderator role already in this codebase
/// (`UserModel.isModerator`/`SessionManager.instance.isModerator`, used for
/// account-wide content moderation — a completely different permission).
class LiveModerator {
  int userId;

  /// Client spec 14.4: guest invite/accept/remove is only available "when
  /// the Host has delegated the required permissions" — unlike pin/mute
  /// (14.2/14.3), which every Moderator can do unconditionally.
  bool canManageGuests;
  int? grantedAt;

  LiveModerator({
    required this.userId,
    this.canManageGuests = false,
    this.grantedAt,
  });

  factory LiveModerator.fromJson(Map<String, dynamic> json) {
    return LiveModerator(
      userId: (json['id'] as num?)?.toInt() ?? -1,
      canManageGuests: json['can_manage_guests'] ?? false,
      grantedAt: json['added_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userId,
      'can_manage_guests': canManageGuests,
      'added_at': grantedAt,
    };
  }
}
