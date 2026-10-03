import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/livestream/pk_invite.dart';

void main() {
  group('isPkInviteExpired', () {
    test('null sentAt is always treated as expired', () {
      expect(
        isPkInviteExpired(sentAt: null, nowMs: 1000, expirySeconds: 60),
        isTrue,
      );
    });

    test('well within the window is not expired', () {
      expect(
        isPkInviteExpired(sentAt: 1000, nowMs: 1000 + 1000, expirySeconds: 60),
        isFalse,
      );
    });

    test('past the window is expired', () {
      expect(
        isPkInviteExpired(
            sentAt: 1000, nowMs: 1000 + 61000, expirySeconds: 60),
        isTrue,
      );
    });

    test('exactly at the boundary counts as expired', () {
      expect(
        isPkInviteExpired(
            sentAt: 1000, nowMs: 1000 + 60000, expirySeconds: 60),
        isTrue,
      );
    });
  });

  group('requiredPkInviteeIds', () {
    test('1v1: the one non-host teammate', () {
      final required =
          requiredPkInviteeIds(teamA: [1], teamB: [2], hostId: 1);
      expect(required, {2});
    });

    test('2v2: everyone except the host, from either team', () {
      final required =
          requiredPkInviteeIds(teamA: [1, 2], teamB: [3, 4], hostId: 1);
      expect(required, {2, 3, 4});
    });

    test('a null hostId removes nobody', () {
      final required =
          requiredPkInviteeIds(teamA: [1], teamB: [2], hostId: null);
      expect(required, {1, 2});
    });
  });

  group('allPkInviteesAccepted', () {
    test('false when nothing is required (no active invite)', () {
      expect(
        allPkInviteesAccepted(required: {}, acceptedIds: [1, 2]),
        isFalse,
      );
    });

    test('false until every required id has accepted', () {
      expect(
        allPkInviteesAccepted(required: {2, 3}, acceptedIds: [2]),
        isFalse,
      );
    });

    test('true once every required id has accepted, order independent', () {
      expect(
        allPkInviteesAccepted(required: {2, 3}, acceptedIds: [3, 2]),
        isTrue,
      );
    });

    test('extra accepted ids beyond what is required are harmless', () {
      expect(
        allPkInviteesAccepted(required: {2}, acceptedIds: [2, 99]),
        isTrue,
      );
    });
  });
}
