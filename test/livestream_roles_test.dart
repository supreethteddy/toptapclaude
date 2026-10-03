import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';

void main() {
  group('LivestreamUserType roles', () {
    test('GUEST is a distinct on-stage role from CO-HOST', () {
      expect(LivestreamUserType.fromString('GUEST'), LivestreamUserType.guest);
      expect(LivestreamUserType.guest.isOnStage, isTrue);
      expect(LivestreamUserType.coHost.isOnStage, isTrue);
      expect(LivestreamUserType.host.isOnStage, isTrue);
      expect(LivestreamUserType.audience.isOnStage, isFalse);
      expect(LivestreamUserType.requested.isOnStage, isFalse);
      expect(LivestreamUserType.guest, isNot(LivestreamUserType.coHost));
    });

    test('only co-host and guest are invitable stage roles', () {
      expect(LivestreamUserType.coHost.isStageRole, isTrue);
      expect(LivestreamUserType.guest.isStageRole, isTrue);
      expect(LivestreamUserType.host.isStageRole, isFalse);
      expect(LivestreamUserType.audience.isStageRole, isFalse);
    });

    test('fromStringOrNull keeps a missing invited_role as null', () {
      expect(LivestreamUserType.fromStringOrNull(null), isNull);
      expect(LivestreamUserType.fromStringOrNull(''), isNull);
      expect(LivestreamUserType.fromStringOrNull('CO-HOST'),
          LivestreamUserType.coHost);
    });

    test('invited_role round-trips through the state doc', () {
      final state = LivestreamUserState.fromJson({
        'type': 'INVITED',
        'user_id': 7,
        'invited_role': 'CO-HOST',
      });
      expect(state.invitedRole, LivestreamUserType.coHost);
      expect(state.toJson()['invited_role'], 'CO-HOST');

      final plain = LivestreamUserState.fromJson({'type': 'AUDIENCE', 'user_id': 8});
      expect(plain.invitedRole, isNull);
      expect(plain.toJson().containsKey('invited_role'), isFalse);
    });
  });

  group('Livestream seat arrays', () {
    // Real room docs always carry type/battle_type; fromJson relies on it.
    Livestream room() => Livestream.fromJson({
          'type': 'LIVESTREAM',
          'battle_type': 'INITIATE',
          'host_id': 1,
          'co-host_ids': [2, 3],
          'guest_ids': [4, 5, 6],
          'pending_seat_ids': [9],
        });

    test('co-hosts and guests are tracked separately', () {
      final r = room();
      expect(r.isCoHost(2), isTrue);
      expect(r.isGuest(2), isFalse);
      expect(r.isGuest(4), isTrue);
      expect(r.isCoHost(4), isFalse);
      expect(r.isOnStage(1), isTrue, reason: 'host is on stage');
      expect(r.isOnStage(9), isFalse, reason: 'a reservation is not a seat');
      expect(r.isOnStage(null), isFalse);
    });

    test('stageIds lists host, then co-hosts, then guests', () {
      expect(room().stageIds, [1, 2, 3, 4, 5, 6]);
    });

    test('older room docs without the new arrays still parse', () {
      final legacy = Livestream.fromJson({
        'type': 'LIVESTREAM',
        'battle_type': 'INITIATE',
        'host_id': 1,
        'co-host_ids': [2],
      });
      expect(legacy.guestIds, isEmpty);
      expect(legacy.pendingSeatIds, isEmpty);
      expect(legacy.stageIds, [1, 2]);
    });

    test('toJson writes both arrays', () {
      final json = room().toJson();
      expect(json['guest_ids'], [4, 5, 6]);
      expect(json['pending_seat_ids'], [9]);
      expect(json['co-host_ids'], [2, 3]);
    });
  });
}
