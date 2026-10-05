import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/livestream_comment.dart';
import 'package:shortzz/model/livestream/pk_gifters.dart';

LivestreamComment _giftComment({
  required int id,
  required int senderId,
  required int receiverId,
  int? giftId,
  int? coinPrice,
}) {
  return LivestreamComment(
    id: id,
    senderId: senderId,
    receiverId: receiverId,
    commentType: LivestreamCommentType.gift,
    giftId: giftId,
    gift: Gift(id: giftId, coinPrice: coinPrice),
  );
}

void main() {
  group('topGiftersForTeam', () {
    const battleCreatedAt = 1000;
    const teamA = [10]; // host
    const teamB = [20]; // co-host

    test('ranks senders by total points, highest first', () {
      final comments = [
        _giftComment(
            id: 1001, senderId: 1, receiverId: 10, giftId: 18, coinPrice: 1),
        _giftComment(
            id: 1002, senderId: 2, receiverId: 10, giftId: null, coinPrice: 5),
        _giftComment(
            id: 1003, senderId: 1, receiverId: 10, giftId: 18, coinPrice: 1),
      ];
      final ranked = topGiftersForTeam(
        comments: comments,
        teamMemberIds: teamA,
        battleCreatedAt: battleCreatedAt,
      );
      expect(ranked.map((r) => r.senderId), [2, 1]);
      expect(ranked.first.points, 5);
    });

    test('ignores gifts sent before this match started', () {
      final comments = [
        _giftComment(
            id: 999, senderId: 1, receiverId: 10, giftId: null, coinPrice: 50),
        _giftComment(
            id: 1001, senderId: 2, receiverId: 10, giftId: null, coinPrice: 1),
      ];
      final ranked = topGiftersForTeam(
        comments: comments,
        teamMemberIds: teamA,
        battleCreatedAt: battleCreatedAt,
      );
      expect(ranked.map((r) => r.senderId), [2]);
    });

    test('only counts gifts sent to this team\'s members', () {
      final comments = [
        _giftComment(
            id: 1001, senderId: 1, receiverId: 10, giftId: null, coinPrice: 3),
        _giftComment(
            id: 1002, senderId: 2, receiverId: 20, giftId: null, coinPrice: 9),
      ];
      final ranksA = topGiftersForTeam(
        comments: comments,
        teamMemberIds: teamA,
        battleCreatedAt: battleCreatedAt,
      );
      final ranksB = topGiftersForTeam(
        comments: comments,
        teamMemberIds: teamB,
        battleCreatedAt: battleCreatedAt,
      );
      expect(ranksA.single.senderId, 1);
      expect(ranksB.single.senderId, 2);
    });

    test('respects an eligible-gift restriction, like live scoring does',
        () {
      final comments = [
        _giftComment(
            id: 1001, senderId: 1, receiverId: 10, giftId: 7, coinPrice: 10),
        _giftComment(
            id: 1002, senderId: 2, receiverId: 10, giftId: 18, coinPrice: 1),
      ];
      final ranked = topGiftersForTeam(
        comments: comments,
        teamMemberIds: teamA,
        battleCreatedAt: battleCreatedAt,
        eligibleGiftIds: [18],
      );
      expect(ranked.map((r) => r.senderId), [2]);
    });

    test('caps the result at the given limit', () {
      final comments = List.generate(
        5,
        (i) => _giftComment(
            id: 1001 + i,
            senderId: i,
            receiverId: 10,
            giftId: null,
            coinPrice: i + 1),
      );
      final ranked = topGiftersForTeam(
        comments: comments,
        teamMemberIds: teamA,
        battleCreatedAt: battleCreatedAt,
        limit: 3,
      );
      expect(ranked.length, 3);
      expect(ranked.map((r) => r.senderId), [4, 3, 2]);
    });

    test('a null battleCreatedAt or empty team yields no gifters', () {
      final comments = [
        _giftComment(
            id: 1001, senderId: 1, receiverId: 10, giftId: null, coinPrice: 1),
      ];
      expect(
          topGiftersForTeam(
              comments: comments,
              teamMemberIds: teamA,
              battleCreatedAt: null),
          isEmpty);
      expect(
          topGiftersForTeam(
              comments: comments,
              teamMemberIds: const [],
              battleCreatedAt: battleCreatedAt),
          isEmpty);
    });

    test('ignores non-gift comments entirely', () {
      final comments = [
        LivestreamComment(
          id: 1001,
          senderId: 1,
          receiverId: 10,
          commentType: LivestreamCommentType.text,
          comment: 'hello',
        ),
      ];
      final ranked = topGiftersForTeam(
        comments: comments,
        teamMemberIds: teamA,
        battleCreatedAt: battleCreatedAt,
      );
      expect(ranked, isEmpty);
    });
  });
}
