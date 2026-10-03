import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/livestream/live_invite.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';

void main() {
  group('LiveInvite', () {
    final created = DateTime(2026, 10, 3, 12, 0, 0);
    final expires = created.add(const Duration(seconds: 60));

    LiveInvite sample() => LiveInvite(
          id: '1_2_1000',
          hostId: 1,
          inviteeId: 2,
          roomId: '1',
          role: LivestreamUserType.coHost,
          hostUsername: 'ram',
          hostFullname: 'Ram',
          hostProfile: 'ram.png',
          status: LiveInviteStatus.pending,
          createdAt: created,
          expiresAt: expires,
        );

    test('round-trips through Firestore JSON (Timestamps included)', () {
      final json = sample().toJson();
      expect(json['created_at'], isA<Timestamp>());
      expect(json['expires_at'], isA<Timestamp>());
      expect(json['role'], 'CO-HOST');
      expect(json['status'], 'pending');

      final restored = LiveInvite.fromJson('1_2_1000', json);
      expect(restored.hostId, 1);
      expect(restored.inviteeId, 2);
      expect(restored.roomId, '1');
      expect(restored.role, LivestreamUserType.coHost);
      expect(restored.hostUsername, 'ram');
      expect(restored.status, LiveInviteStatus.pending);
      expect(restored.createdAt, created);
      expect(restored.expiresAt, expires);
    });

    test('an unknown or missing role defaults to GUEST, never CO-HOST', () {
      final noRole = LiveInvite.fromJson('x', {'host_id': 1, 'invitee_id': 2});
      expect(noRole.role, LivestreamUserType.guest);
      final badRole = LiveInvite.fromJson(
          'y', {'host_id': 1, 'invitee_id': 2, 'role': 'WIZARD'});
      expect(badRole.role, LivestreamUserType.guest);
    });

    test('expiry is inclusive at the boundary', () {
      final invite = sample();
      expect(invite.isExpiredAt(created), isFalse);
      expect(invite.isExpiredAt(expires.subtract(const Duration(seconds: 1))),
          isFalse);
      expect(invite.isExpiredAt(expires), isTrue);
      expect(invite.isExpiredAt(expires.add(const Duration(minutes: 5))), isTrue);
    });

    test('status parsing is tolerant of unknown values', () {
      expect(LiveInviteStatus.fromValue('seatsFull'), LiveInviteStatus.seatsFull);
      expect(LiveInviteStatus.fromValue('nope'), isNull);
      expect(LiveInviteStatus.fromValue(null), isNull);
      final weird = LiveInvite.fromJson('z', {'status': 'nope'});
      expect(weird.status, LiveInviteStatus.pending);
      expect(weird.isPending, isTrue);
    });

    test('accepts epoch-millis timestamps written by older clients', () {
      final invite = LiveInvite.fromJson('m', {
        'host_id': 1,
        'invitee_id': 2,
        'created_at': created.millisecondsSinceEpoch,
        'expires_at': expires.millisecondsSinceEpoch,
      });
      expect(invite.createdAt, created);
      expect(invite.expiresAt, expires);
    });
  });
}
