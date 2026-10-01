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
  final List<int> participantHostIds; // always length 2: [me, opponent]
  final List<String> roomIds; // length 2 (cross-room) or 1 (same-room)
  final Map<String, int> finalScores; // key = hostId.toString()
  final Map<String, int> roundsWon; // key = hostId.toString()
  final int? winnerHostId; // null when isDraw
  final bool isDraw;
  final int totalRounds;
  final int? battleCreatedAt; // ms epoch, from Livestream.battleCreatedAt
  final int battleEndedAt; // ms epoch, client clock at write time
  final String endReason; // 'timer_expired' | 'manual_stop' | 'opponent_disconnected'

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
  });

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
      );

  /// The other participant's id, given my own — used by the history screen
  /// (one query returns battles from both sides, each row needs to show
  /// "you" vs. "them" without the caller re-deriving list logic).
  ///
  /// Returns null if [myUserId] isn't actually one of the two participants
  /// (an earlier version used `firstWhere((id) => id != myUserId)` alone,
  /// which — for a userId that's a stranger to this battle entirely — just
  /// returns the first participant id, since both ids are "not equal to"
  /// a stranger; caught by this file's own unit test).
  int? opponentIdFor(int myUserId) {
    if (!participantHostIds.contains(myUserId)) return null;
    for (final id in participantHostIds) {
      if (id != myUserId) return id;
    }
    return null;
  }

  int scoreFor(int hostId) => finalScores['$hostId'] ?? 0;

  int roundsWonFor(int hostId) => roundsWon['$hostId'] ?? 0;
}
