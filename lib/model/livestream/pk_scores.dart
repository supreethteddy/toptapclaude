import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/utilities/app_res.dart';

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
  // Client spec (Module 8.1): no matter how many taps land, tap-tap can
  // only ever contribute up to tapTapMaxPkPointsPerMatch to this side's PK
  // score for the whole match -- likeEvents itself (pkLikePointsA/B,
  // crossRoomLikePoints) is still incremented without limit on every tap
  // (see onLikeButtonTap), only the score contribution computed here caps.
  final rawLikes =
      (likeEvents.clamp(0, 1 << 31)) * pointsPerLike.clamp(0, 1 << 20);
  final likes = rawLikes.clamp(0, AppRes.tapTapMaxPkPointsPerMatch);
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
  if (myUserId != null && winners.contains(myUserId))
    return PkPersonalResult.won;
  if (myUserId != null && losers.contains(myUserId))
    return PkPersonalResult.lost;
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

/// Client spec 9.4 (clarified 2026-10-26): the post-match window is 3
/// minutes total from the moment a battle ends, on the EXISTING arena
/// screen -- never a separate screen, never gating any action (a rematch
/// or leaving the room both work at any point regardless of phase, see
/// LivestreamScreenController.startNextRound/requestRematch/
/// onStopButtonTap, none of which reference this).
enum PostBattlePhase {
  /// No battle has just ended (battleType != end) -- nothing to show.
  active,

  /// First AppRes.battleResultsVisibleDurationInSecond (60s): full match
  /// results -- scores, gifting details, gift-sender lists, match activity.
  fullResults,

  /// From there until AppRes.pkVictoryLapDurationInSecond (180s total from
  /// battle end): scores/gifting-details/match-activity hidden, a plain
  /// "Victory Lap" display stays up so players can enjoy gift animations
  /// and keep talking -- no new controls, nothing else changes.
  victoryLap,

  /// Past 180s -- the arena should have already reset to the normal view
  /// (see LivestreamExistMessageBar); treated the same as [active] by any
  /// caller that reaches this before that write lands.
  reset,
}

PostBattlePhase postBattlePhaseFor({
  required BattleType? battleType,
  required int? battleEndedAt,
  DateTime? now,
}) {
  if (battleType != BattleType.end) return PostBattlePhase.active;
  if (battleEndedAt == null) return PostBattlePhase.fullResults;
  final elapsedSeconds =
      ((now ?? DateTime.now()).millisecondsSinceEpoch - battleEndedAt) / 1000;
  if (elapsedSeconds < AppRes.battleResultsVisibleDurationInSecond) {
    return PostBattlePhase.fullResults;
  }
  if (elapsedSeconds < AppRes.pkVictoryLapDurationInSecond) {
    return PostBattlePhase.victoryLap;
  }
  return PostBattlePhase.reset;
}
