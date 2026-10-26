/// Which side a battle (or a single round of one) resolved to, given two
/// final scores. A pure function on purpose — every place that previously
/// computed this inline (`battle_view.dart`, `party_battle_view.dart`,
/// `startNextRound`, `_recordBattleHistory`) used `red >= blue`, which
/// silently counted a tie as a win for the first side. Centralizing it here
/// means it's both consistent everywhere and directly unit-testable without
/// needing a widget or a Firestore round-trip.
enum BattleOutcome { sideAWins, sideBWins, draw }

BattleOutcome determineBattleOutcome(int scoreA, int scoreB) {
  if (scoreA == scoreB) return BattleOutcome.draw;
  return scoreA > scoreB ? BattleOutcome.sideAWins : BattleOutcome.sideBWins;
}

/// Immutable record of one completed (or abandoned) PK Battle.
///
/// Nothing like this existed before — a battle's outcome was computed only
/// for one render (`battle_view.dart`'s win/draw check) and discarded the
/// moment the host dismissed the result (`endCrossRoomBattleAndReset`
/// zeroes everything). This is written once, right before that reset runs,
/// so a battle's result survives after both rooms go back to normal.
///
/// Stored at `battle_history/{battleId}`. Both participants can find their
/// own battles with a single query: `where('participantHostIds',
/// arrayContains: myUserId)` — no need for two separate documents or two
/// different query shapes depending on which side you were on.
class BattleResult {
  final String battleId;
  final bool isCrossRoom;
  // 1v1: length 2, [me, opponent]. 2v2 (client spec Module 6/7): length 4,
  // every individual across both teams -- see [teamAHostIds]/[teamBHostIds]
  // for which side each one is on.
  final List<int> participantHostIds;
  final List<String> roomIds; // length 2 (cross-room) or 1 (same-room)
  final Map<String, int> finalScores; // key = hostId.toString(), per individual
  final Map<String, int> roundsWon; // key = hostId.toString()
  final int? winnerHostId; // the winning side's primary host; null when isDraw
  final bool isDraw;
  final int totalRounds;
  final int? battleCreatedAt; // ms epoch, from Livestream.battleCreatedAt
  final int battleEndedAt; // ms epoch, client clock at write time
  final String endReason; // 'timer_expired' | 'manual_stop' | 'opponent_disconnected'
  // Null for a 1v1 battle recorded before this field existed, or a 1v1
  // battle where team == [primary host] is already implied by
  // participantHostIds itself. Set for every 2v2 battle (client spec 7.1:
  // "the backend must keep individual scores and team totals
  // synchronized") -- teamATotal/teamBTotal are deliberately NOT stored
  // separately; sum finalScores over these ids instead, so there's exactly
  // one source of truth per individual score.
  final List<int>? teamAHostIds;
  final List<int>? teamBHostIds;

  const BattleResult({
    required this.battleId,
    required this.isCrossRoom,
    required this.participantHostIds,
    required this.roomIds,
    required this.finalScores,
    required this.roundsWon,
    required this.winnerHostId,
    required this.isDraw,
    required this.totalRounds,
    required this.battleCreatedAt,
    required this.battleEndedAt,
    required this.endReason,
    this.teamAHostIds,
    this.teamBHostIds,
  });

  bool get isTeamBattle => (teamAHostIds?.length ?? 1) > 1;

  Map<String, dynamic> toJson() => {
        'battle_id': battleId,
        'is_cross_room': isCrossRoom,
        'participant_host_ids': participantHostIds,
        'room_ids': roomIds,
        'final_scores': finalScores,
        'rounds_won': roundsWon,
        'winner_host_id': winnerHostId,
        'is_draw': isDraw,
        'total_rounds': totalRounds,
        'battle_created_at': battleCreatedAt,
        'battle_ended_at': battleEndedAt,
        'end_reason': endReason,
        if (teamAHostIds != null) 'team_a_host_ids': teamAHostIds,
        if (teamBHostIds != null) 'team_b_host_ids': teamBHostIds,
      };

  factory BattleResult.fromJson(Map<String, dynamic> json) => BattleResult(
        battleId: json['battle_id'] ?? '',
        isCrossRoom: json['is_cross_room'] ?? false,
        participantHostIds: List<int>.from(json['participant_host_ids'] ?? const []),
        roomIds: List<String>.from(json['room_ids'] ?? const []),
        finalScores: Map<String, int>.from(json['final_scores'] ?? const {}),
        roundsWon: Map<String, int>.from(json['rounds_won'] ?? const {}),
        winnerHostId: json['winner_host_id'],
        isDraw: json['is_draw'] ?? false,
        totalRounds: json['total_rounds'] ?? 0,
        battleCreatedAt: json['battle_created_at'],
        battleEndedAt: json['battle_ended_at'] ?? 0,
        endReason: json['end_reason'] ?? 'unknown',
        teamAHostIds: json['team_a_host_ids'] == null
            ? null
            : List<int>.from(json['team_a_host_ids']),
        teamBHostIds: json['team_b_host_ids'] == null
            ? null
            : List<int>.from(json['team_b_host_ids']),
      );

  /// Which team (A or B) [hostId] played on. Falls back to treating
  /// [participantHostIds] as two solo teams of one (1v1, or a battle
  /// recorded before team ids existed) when [teamAHostIds]/[teamBHostIds]
  /// are null.
  List<int> _teamOf(int hostId) {
    final a = teamAHostIds;
    final b = teamBHostIds;
    if (a != null && a.contains(hostId)) return a;
    if (b != null && b.contains(hostId)) return b;
    if (a == null && b == null && participantHostIds.contains(hostId)) {
      return [hostId];
    }
    return const [];
  }

  /// One opposing-team participant's id, given my own — used by the
  /// history screen (one query returns battles from both sides, each row
  /// needs to show "you" vs. "them" without the caller re-deriving list
  /// logic). Team-aware: for a 2v2 battle, a naive "any id that isn't me"
  /// could return my own teammate instead of an actual opponent.
  ///
  /// Returns null if [myUserId] isn't actually one of the participants (an
  /// earlier version used `firstWhere((id) => id != myUserId)` alone,
  /// which — for a userId that's a stranger to this battle entirely — just
  /// returns the first participant id, since both ids are "not equal to"
  /// a stranger; caught by this file's own unit test).
  int? opponentIdFor(int myUserId) {
    if (!participantHostIds.contains(myUserId)) return null;
    final myTeam = _teamOf(myUserId).toSet();
    for (final id in participantHostIds) {
      if (!myTeam.contains(id)) return id;
    }
    return null;
  }

  /// Every participant on the opposing team from [myUserId]'s side --
  /// `[opponentIdFor(myUserId)]` for 1v1, two ids for 2v2. Used where a
  /// caller wants the whole opposing side, not just one representative.
  List<int> opponentTeamFor(int myUserId) {
    if (!participantHostIds.contains(myUserId)) return const [];
    final myTeam = _teamOf(myUserId).toSet();
    return participantHostIds.where((id) => !myTeam.contains(id)).toList();
  }

  /// True when [hostId]'s own team is the winning one -- team-aware, so a
  /// 2v2 teammate who isn't [winnerHostId] itself (that field only ever
  /// holds the winning side's primary host) still correctly reads as a
  /// winner.
  bool wonBy(int hostId) {
    if (isDraw || winnerHostId == null) return false;
    if (hostId == winnerHostId) return true;
    return _teamOf(hostId).contains(winnerHostId);
  }

  int scoreFor(int hostId) => finalScores['$hostId'] ?? 0;

  /// Sum of [scoreFor] over everyone on [hostId]'s own team -- the team
  /// total client spec 7.1 requires alongside each individual score.
  int teamTotalFor(int hostId) =>
      _teamOf(hostId).fold(0, (sum, id) => sum + scoreFor(id));

  int roundsWonFor(int hostId) => roundsWon['$hostId'] ?? 0;
}
