/// One row of the per-LIVE moderation audit trail (client spec 14.5:
/// "record moderation actions in the audit log"). Append-only from the
/// client's side — written once per action, never edited.
class ModerationLogEntry {
  int? actorId;
  String? actorUsername;
  String? action;
  int? targetId;
  String? targetUsername;
  String? detail;
  int? at;

  ModerationLogEntry({
    this.actorId,
    this.actorUsername,
    this.action,
    this.targetId,
    this.targetUsername,
    this.detail,
    this.at,
  });

  factory ModerationLogEntry.fromJson(Map<String, dynamic> json) {
    return ModerationLogEntry(
      actorId: json['actor_id'],
      actorUsername: json['actor_username'],
      action: json['action'],
      targetId: json['target_id'],
      targetUsername: json['target_username'],
      detail: json['detail'],
      at: json['at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actor_id': actorId,
      'actor_username': actorUsername,
      'action': action,
      'target_id': targetId,
      'target_username': targetUsername,
      'detail': detail,
      'at': at,
    };
  }
}
