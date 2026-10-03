import 'package:shortzz/model/livestream/battle_result.dart';

/// One side's PK score. Team score = sum of its members' eligible-gift
/// points (minus any per-round baseline) + likes credited to that side.
class PkTeamScore {
  final List<int> memberIds;
  final int giftPoints;
  final int likePoints;

  const PkTeamScore({
    required this.memberIds,
    required this.giftPoints,
    required this.likePoints,
  });

  int get total => giftPoints + likePoints;
}

/// [battleCoinByUser] is each participant's `current_battle_coin`;
/// [baselineByUser] is what it was when the current round started (so a
/// round starts from zero without resetting Firestore counters);
/// [likeEvents] is this side's raw like tap count, worth [pointsPerLike]
/// each (admin "PK points per like").
PkTeamScore pkTeamScore({
  required List<int> memberIds,
  required Map<int, int> battleCoinByUser,
  Map<int, int> baselineByUser = const {},
  int likeEvents = 0,
  int pointsPerLike = 1,
}) {
  var gift = 0;
  for (final id in memberIds) {
    final raw = battleCoinByUser[id] ?? 0;
    final base = baselineByUser[id] ?? 0;
    gift += (raw - base).clamp(0, 1 << 31);
  }
  final likes = (likeEvents.clamp(0, 1 << 31)) * pointsPerLike.clamp(0, 1 << 20);
  return PkTeamScore(memberIds: memberIds, giftPoints: gift, likePoints: likes);
}

/// Shared outcome rule (ties are a draw, never a win for either side).
BattleOutcome pkOutcome(PkTeamScore a, PkTeamScore b) =>
    determineBattleOutcome(a.total, b.total);

/// What a specific viewer should be told at the end: PK players get a
/// personal result, everyone else sees the neutral one.
enum PkPersonalResult { won, lost, draw, spectator }

PkPersonalResult pkPersonalResult({
  required BattleOutcome outcome,
  required int? myUserId,
  required List<int> teamA,
  required List<int> teamB,
}) {
  if (outcome == BattleOutcome.draw) {
    final playing = myUserId != null &&
        (teamA.contains(myUserId) || teamB.contains(myUserId));
    return playing ? PkPersonalResult.draw : PkPersonalResult.spectator;
  }
  final winners = outcome == BattleOutcome.sideAWins ? teamA : teamB;
  final losers = outcome == BattleOutcome.sideAWins ? teamB : teamA;
  if (myUserId != null && winners.contains(myUserId)) return PkPersonalResult.won;
  if (myUserId != null && losers.contains(myUserId)) return PkPersonalResult.lost;
  return PkPersonalResult.spectator;
}

/// Client spec: win with a smiling emoji, lose with a crying one.
String pkEmojiFor(PkPersonalResult result) => switch (result) {
      PkPersonalResult.won => '😄',
      PkPersonalResult.lost => '😢',
      PkPersonalResult.draw => '🤝',
      PkPersonalResult.spectator => '',
    };

/// Emoji shown on each side's tag for everyone (winner smiles, loser cries,
/// both shake hands on a draw).
String pkSideEmoji({required BattleOutcome outcome, required bool isSideA}) {
  if (outcome == BattleOutcome.draw) return '🤝';
  final sideWon = isSideA
      ? outcome == BattleOutcome.sideAWins
      : outcome == BattleOutcome.sideBWins;
  return sideWon ? '😄' : '😢';
}
