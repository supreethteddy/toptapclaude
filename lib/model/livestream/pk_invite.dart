// Pure decision logic for the same-room PK Match invitation lifecycle
// (lib/screen/live_stream/livestream_screen/livestream_screen_controller.dart
// holds the Firestore transactions that read/write these; this file only
// answers "given this state, what should happen" so it's testable without
// Firestore or Zego).

/// True once [sentAt] (ms epoch) is more than [expirySeconds] old, or if
/// there was never a [sentAt] to begin with — a missing timestamp is never
/// treated as "still fresh".
bool isPkInviteExpired({
  required int? sentAt,
  required int nowMs,
  required int expirySeconds,
}) {
  if (sentAt == null) return true;
  return (nowMs - sentAt) / 1000 >= expirySeconds;
}

/// Every player who must explicitly accept before the match can start — both
/// teams, minus the host (sending the invite is the host's own consent).
Set<int> requiredPkInviteeIds({
  required List<int> teamA,
  required List<int> teamB,
  required int? hostId,
}) {
  final ids = <int>{...teamA, ...teamB};
  if (hostId != null) ids.remove(hostId);
  return ids;
}

/// False when there is nothing to wait on (e.g. the invite was already
/// cleared) as well as when someone required still hasn't accepted — both
/// cases mean "don't start the match yet".
bool allPkInviteesAccepted({
  required Set<int> required,
  required List<int> acceptedIds,
}) {
  if (required.isEmpty) return false;
  return required.every(acceptedIds.contains);
}
