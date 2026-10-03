import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/model/livestream/pk_scores.dart';

void main() {
  group('pkTeamScore', () {
    test('2v2 team score is the sum of both members plus like points', () {
      final a = pkTeamScore(
        memberIds: [1, 3],
        battleCoinByUser: {1: 40, 2: 100, 3: 10, 4: 5},
        likeEvents: 7,
        pointsPerLike: 2,
      );
      expect(a.giftPoints, 50);
      expect(a.likePoints, 14);
      expect(a.total, 64);
    });

    test('per-round baseline is subtracted and never goes negative', () {
      final s = pkTeamScore(
        memberIds: [1, 3],
        battleCoinByUser: {1: 40, 3: 10},
        baselineByUser: {1: 30, 3: 25}, // 3's counter was reset below baseline
      );
      expect(s.giftPoints, 10);
    });

    test('members with no counter yet score zero, likes default to 1 point', () {
      final s = pkTeamScore(memberIds: [9], battleCoinByUser: {}, likeEvents: 3);
      expect(s.giftPoints, 0);
      expect(s.likePoints, 3);
    });
  });

  group('pkOutcome', () {
    PkTeamScore side(int gift, int like) =>
        PkTeamScore(memberIds: const [0], giftPoints: gift, likePoints: like);

    test('higher total wins, likes can decide it', () {
      expect(pkOutcome(side(10, 0), side(9, 0)), BattleOutcome.sideAWins);
      expect(pkOutcome(side(10, 0), side(9, 2)), BattleOutcome.sideBWins);
    });

    test('equal totals are a draw', () {
      expect(pkOutcome(side(5, 5), side(10, 0)), BattleOutcome.draw);
    });
  });

  group('personal result + emoji', () {
    const teamA = [1, 3];
    const teamB = [2, 4];

    test('players on the winning side won, losing side lost', () {
      expect(
          pkPersonalResult(
              outcome: BattleOutcome.sideAWins,
              myUserId: 3,
              teamA: teamA,
              teamB: teamB),
          PkPersonalResult.won);
      expect(
          pkPersonalResult(
              outcome: BattleOutcome.sideAWins,
              myUserId: 4,
              teamA: teamA,
              teamB: teamB),
          PkPersonalResult.lost);
    });

    test('viewers are spectators; a draw is a draw only for players', () {
      expect(
          pkPersonalResult(
              outcome: BattleOutcome.sideBWins,
              myUserId: 99,
              teamA: teamA,
              teamB: teamB),
          PkPersonalResult.spectator);
      expect(
          pkPersonalResult(
              outcome: BattleOutcome.draw, myUserId: 1, teamA: teamA, teamB: teamB),
          PkPersonalResult.draw);
      expect(
          pkPersonalResult(
              outcome: BattleOutcome.draw,
              myUserId: 99,
              teamA: teamA,
              teamB: teamB),
          PkPersonalResult.spectator);
      expect(
          pkPersonalResult(
              outcome: BattleOutcome.sideAWins,
              myUserId: null,
              teamA: teamA,
              teamB: teamB),
          PkPersonalResult.spectator);
    });

    test('win smiles, loss cries, draw shakes hands', () {
      expect(pkEmojiFor(PkPersonalResult.won), '😄');
      expect(pkEmojiFor(PkPersonalResult.lost), '😢');
      expect(pkEmojiFor(PkPersonalResult.draw), '🤝');
      expect(pkEmojiFor(PkPersonalResult.spectator), '');
    });

    test('side tags mirror the outcome', () {
      expect(pkSideEmoji(outcome: BattleOutcome.sideAWins, isSideA: true), '😄');
      expect(pkSideEmoji(outcome: BattleOutcome.sideAWins, isSideA: false), '😢');
      expect(pkSideEmoji(outcome: BattleOutcome.sideBWins, isSideA: true), '😢');
      expect(pkSideEmoji(outcome: BattleOutcome.draw, isSideA: true), '🤝');
    });
  });
}
