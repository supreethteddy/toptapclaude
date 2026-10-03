import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/livestream/pk_eligibility.dart';

void main() {
  group('pkEligibilityFor', () {
    test('host alone: no PK', () {
      final e = pkEligibilityFor(
          hostId: 1, coHostIds: [], guestIds: [], publishingIds: {1});
      expect(e.mode, PkMode.none);
      expect(e.reason, PkIneligibleReason.hostAlone);
      expect(e.isAvailable, isFalse);
    });

    test('host + 1 publishing co-host: 1v1', () {
      final e = pkEligibilityFor(
          hostId: 1, coHostIds: [2], guestIds: [], publishingIds: {1, 2});
      expect(e.mode, PkMode.oneVsOne);
      expect(e.eligibleIds, [1, 2]);
      expect(e.playersNeeded, 2);
    });

    test('host + 3 publishing co-hosts: 2v2', () {
      final e = pkEligibilityFor(
          hostId: 1,
          coHostIds: [2, 3, 4],
          guestIds: [],
          publishingIds: {1, 2, 3, 4});
      expect(e.mode, PkMode.twoVsTwo);
      expect(e.eligibleIds, [1, 2, 3, 4]);
      expect(e.playersNeeded, 4);
    });

    test('host + 2 co-hosts (3 eligible): no PK, explains why', () {
      final e = pkEligibilityFor(
          hostId: 1, coHostIds: [2, 3], guestIds: [], publishingIds: {1, 2, 3});
      expect(e.mode, PkMode.none);
      expect(e.reason, PkIneligibleReason.needEvenTeams);
    });

    test('Guest Call participants are never counted, however many', () {
      // Host + 1 co-host + 2 guests all publishing -> still a 1v1, not 2v2.
      final e = pkEligibilityFor(
          hostId: 1,
          coHostIds: [2],
          guestIds: [5, 6],
          publishingIds: {1, 2, 5, 6});
      expect(e.mode, PkMode.oneVsOne);
      expect(e.eligibleIds, [1, 2]);

      // Host + 3 guests, no co-hosts -> host alone as far as PK is concerned.
      final onlyGuests = pkEligibilityFor(
          hostId: 1,
          coHostIds: [],
          guestIds: [5, 6, 7],
          publishingIds: {1, 5, 6, 7});
      expect(onlyGuests.mode, PkMode.none);
      expect(onlyGuests.reason, PkIneligibleReason.hostAlone);
    });

    test('a user listed in both arrays is treated as a guest (safe side)', () {
      final e = pkEligibilityFor(
          hostId: 1, coHostIds: [2, 3], guestIds: [3], publishingIds: {1, 2, 3});
      expect(e.mode, PkMode.oneVsOne);
      expect(e.eligibleIds, [1, 2]);
    });

    test('a co-host whose stream dropped is not eligible until it is back',
        () {
      final e = pkEligibilityFor(
          hostId: 1, coHostIds: [2, 3, 4], guestIds: [], publishingIds: {1, 2, 3});
      expect(e.mode, PkMode.none);
      expect(e.reason, PkIneligibleReason.needEvenTeams);
      expect(e.eligibleIds, [1, 2, 3]);
    });

    test('host not publishing or battles disabled: no PK', () {
      expect(
          pkEligibilityFor(
                  hostId: 1, coHostIds: [2], guestIds: [], publishingIds: {2})
              .reason,
          PkIneligibleReason.hostNotPublishing);
      expect(
          pkEligibilityFor(
                  hostId: 1,
                  coHostIds: [2],
                  guestIds: [],
                  publishingIds: {1, 2},
                  battleEnabled: false)
              .reason,
          PkIneligibleReason.battleDisabled);
    });

    test('more than 4 eligible (misconfigured cap) is refused', () {
      final e = pkEligibilityFor(
          hostId: 1,
          coHostIds: [2, 3, 4, 5],
          guestIds: [],
          publishingIds: {1, 2, 3, 4, 5});
      expect(e.mode, PkMode.none);
      expect(e.reason, PkIneligibleReason.tooMany);
    });
  });

  group('giftCountsForPk', () {
    test('null or empty eligible list means every gift counts', () {
      expect(giftCountsForPk(18, null), isTrue);
      expect(giftCountsForPk(18, []), isTrue);
    });

    test('a configured list is exclusive', () {
      expect(giftCountsForPk(18, [18, 20]), isTrue);
      expect(giftCountsForPk(19, [18, 20]), isFalse);
      expect(giftCountsForPk(null, [18]), isFalse);
    });
  });

  group('validatePkTeams', () {
    final twoVsTwo = pkEligibilityFor(
        hostId: 1, coHostIds: [2, 3, 4], guestIds: [], publishingIds: {1, 2, 3, 4});
    final oneVsOne = pkEligibilityFor(
        hostId: 1, coHostIds: [2], guestIds: [], publishingIds: {1, 2});

    test('accepts a valid 2v2 split with the host on team A', () {
      expect(
          validatePkTeams(
              eligibility: twoVsTwo, hostId: 1, teamA: [1, 3], teamB: [2, 4]),
          isNull);
    });

    test('accepts the only valid 1v1 split', () {
      expect(
          validatePkTeams(
              eligibility: oneVsOne, hostId: 1, teamA: [1], teamB: [2]),
          isNull);
    });

    test('rejects wrong sizes, duplicates, host on team B, outsiders', () {
      expect(
          validatePkTeams(
              eligibility: twoVsTwo, hostId: 1, teamA: [1], teamB: [2, 3, 4]),
          'team_size');
      expect(
          validatePkTeams(
              eligibility: twoVsTwo, hostId: 1, teamA: [1, 2], teamB: [2, 3]),
          'duplicate_player');
      expect(
          validatePkTeams(
              eligibility: twoVsTwo, hostId: 1, teamA: [2, 3], teamB: [1, 4]),
          'host_not_on_team_a');
      expect(
          validatePkTeams(
              eligibility: twoVsTwo, hostId: 1, teamA: [1, 9], teamB: [2, 3]),
          'ineligible_player');
      final none = pkEligibilityFor(
          hostId: 1, coHostIds: [], guestIds: [], publishingIds: {1});
      expect(validatePkTeams(eligibility: none, hostId: 1, teamA: [1], teamB: []),
          'mode_unavailable');
    });
  });
}
