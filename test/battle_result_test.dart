import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/livestream/battle_result.dart';

void main() {
  group('determineBattleOutcome', () {
    test('higher score on side A wins', () {
      expect(determineBattleOutcome(10, 5), BattleOutcome.sideAWins);
    });

    test('higher score on side B wins', () {
      expect(determineBattleOutcome(5, 10), BattleOutcome.sideBWins);
    });

    test('equal scores are a draw, not a win for either side', () {
      // This is the exact bug that was found and fixed in battle_view.dart /
      // party_battle_view.dart / startNextRound, all of which used to treat
      // `scoreA >= scoreB` as "A wins", silently swallowing every tie.
      expect(determineBattleOutcome(0, 0), BattleOutcome.draw);
      expect(determineBattleOutcome(42, 42), BattleOutcome.draw);
    });
  });

  group('BattleResult', () {
    BattleResult sample() => const BattleResult(
          battleId: '1_2_1000',
          isCrossRoom: true,
          participantHostIds: [1, 2],
          roomIds: ['1', '2'],
          finalScores: {'1': 50, '2': 30},
          roundsWon: {'1': 2, '2': 0},
          winnerHostId: 1,
          isDraw: false,
          totalRounds: 2,
          battleCreatedAt: 1000,
          battleEndedAt: 2000,
          endReason: 'timer_expired',
        );

    test('round-trips through JSON without losing data', () {
      final result = sample();
      final restored = BattleResult.fromJson(result.toJson());

      expect(restored.battleId, result.battleId);
      expect(restored.isCrossRoom, result.isCrossRoom);
      expect(restored.participantHostIds, result.participantHostIds);
      expect(restored.roomIds, result.roomIds);
      expect(restored.finalScores, result.finalScores);
      expect(restored.roundsWon, result.roundsWon);
      expect(restored.winnerHostId, result.winnerHostId);
      expect(restored.isDraw, result.isDraw);
      expect(restored.totalRounds, result.totalRounds);
      expect(restored.battleCreatedAt, result.battleCreatedAt);
      expect(restored.battleEndedAt, result.battleEndedAt);
      expect(restored.endReason, result.endReason);
    });

    test('opponentIdFor returns the other participant', () {
      final result = sample();
      expect(result.opponentIdFor(1), 2);
      expect(result.opponentIdFor(2), 1);
    });

    test('opponentIdFor returns null for a user not in the battle', () {
      final result = sample();
      expect(result.opponentIdFor(999), isNull);
    });

    test('scoreFor and roundsWonFor read the right side', () {
      final result = sample();
      expect(result.scoreFor(1), 50);
      expect(result.scoreFor(2), 30);
      expect(result.roundsWonFor(1), 2);
      expect(result.roundsWonFor(2), 0);
    });

    test('scoreFor defaults to 0 for an id with no recorded score', () {
      final result = sample();
      expect(result.scoreFor(999), 0);
    });

    test('a draw result has no winnerHostId', () {
      const draw = BattleResult(
        battleId: '1_2_1000',
        isCrossRoom: true,
        participantHostIds: [1, 2],
        roomIds: ['1', '2'],
        finalScores: {'1': 20, '2': 20},
        roundsWon: {'1': 1, '2': 1},
        winnerHostId: null,
        isDraw: true,
        totalRounds: 2,
        battleCreatedAt: 1000,
        battleEndedAt: 2000,
        endReason: 'timer_expired',
      );
      final restored = BattleResult.fromJson(draw.toJson());
      expect(restored.isDraw, isTrue);
      expect(restored.winnerHostId, isNull);
    });
  });
}
