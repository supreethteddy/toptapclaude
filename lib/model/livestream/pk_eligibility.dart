/// Which PK Match the room can currently offer, derived ONLY from roles:
/// the host plus Co-host Mode participants who are actually publishing.
/// Guest Call participants are never counted - the client requires that a
/// guest can't become a PK player by merely being visible on screen.
enum PkMode { none, oneVsOne, twoVsTwo }

/// Why [PkMode.none] - so the Match button can say what's missing instead
/// of silently disappearing.
enum PkIneligibleReason {
  battleDisabled,
  hostNotPublishing,
  hostAlone,
  needEvenTeams, // 3 eligible: 1v1 needs exactly 2, 2v2 exactly 4
  tooMany, // > 4 eligible (cap misconfigured or legacy room)
}

class PkEligibility {
  final PkMode mode;

  /// Host first, then co-hosts in room order - the default team seed.
  final List<int> eligibleIds;
  final PkIneligibleReason? reason;

  const PkEligibility._(this.mode, this.eligibleIds, this.reason);

  bool get isAvailable => mode != PkMode.none;

  int get playersNeeded => switch (mode) {
        PkMode.oneVsOne => 2,
        PkMode.twoVsTwo => 4,
        PkMode.none => 0,
      };
}

/// Pure function so it can be unit-tested and reused by the Match button,
/// the setup sheet and the start-time re-validation alike.
///
/// [publishingIds] = user ids that currently have a live stream in the
/// room (what `streamViews` holds); a co-host whose stream dropped is not
/// eligible until it's back.
PkEligibility pkEligibilityFor({
  required int? hostId,
  required List<int> coHostIds,
  required List<int> guestIds,
  required Set<int> publishingIds,
  bool battleEnabled = true,
}) {
  if (!battleEnabled) {
    return const PkEligibility._(PkMode.none, [], PkIneligibleReason.battleDisabled);
  }
  if (hostId == null || !publishingIds.contains(hostId)) {
    return const PkEligibility._(
        PkMode.none, [], PkIneligibleReason.hostNotPublishing);
  }
  final guests = guestIds.toSet();
  final eligible = <int>[
    hostId,
    for (final id in coHostIds)
      if (id != hostId && !guests.contains(id) && publishingIds.contains(id)) id,
  ];
  switch (eligible.length) {
    case 1:
      return PkEligibility._(PkMode.none, eligible, PkIneligibleReason.hostAlone);
    case 2:
      return PkEligibility._(PkMode.oneVsOne, eligible, null);
    case 3:
      return PkEligibility._(
          PkMode.none, eligible, PkIneligibleReason.needEvenTeams);
    case 4:
      return PkEligibility._(PkMode.twoVsTwo, eligible, null);
    default:
      return PkEligibility._(PkMode.none, eligible, PkIneligibleReason.tooMany);
  }
}

/// Whether a gift scores points in the current match. An empty/null
/// eligible list means the host chose "all gifts".
bool giftCountsForPk(int? giftId, List<int>? eligibleGiftIds) {
  if (eligibleGiftIds == null || eligibleGiftIds.isEmpty) return true;
  if (giftId == null) return false;
  return eligibleGiftIds.contains(giftId);
}

/// Validates a proposed team split against the eligibility result: every
/// player must be eligible, nobody on both teams, host on team A, sizes
/// match the mode. Returns null when valid, else a short reason key.
String? validatePkTeams({
  required PkEligibility eligibility,
  required int hostId,
  required List<int> teamA,
  required List<int> teamB,
}) {
  final size = eligibility.playersNeeded ~/ 2;
  if (size == 0) return 'mode_unavailable';
  if (teamA.length != size || teamB.length != size) return 'team_size';
  if (!teamA.contains(hostId)) return 'host_not_on_team_a';
  final all = [...teamA, ...teamB];
  if (all.toSet().length != all.length) return 'duplicate_player';
  final eligible = eligibility.eligibleIds.toSet();
  if (!all.every(eligible.contains)) return 'ineligible_player';
  return null;
}
