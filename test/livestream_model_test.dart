import 'package:flutter_test/flutter_test.dart';
import 'package:toptap/model/livestream/livestream.dart';
import 'package:toptap/model/livestream/livestream_user_state.dart';

void main() {
  group('Livestream compatibility', () {
    test('older stream documents keep comments enabled', () {
      final stream = Livestream.fromJson(<String, dynamic>{
        'type': 'LIVESTREAM',
        'room_id': '42',
      });

      expect(stream.commentsEnabled, isTrue);
    });

    test('comment setting is persisted', () {
      final stream = Livestream(commentsEnabled: false);

      expect(stream.toJson()['comments_enabled'], isFalse);
    });
  });

  group('Livestream user state compatibility', () {
    test('missing follower history is treated as empty', () {
      final state = LivestreamUserState.fromJson(<String, dynamic>{
        'user_id': 42,
      });

      expect(state.followersGained, isEmpty);
    });

    test('numeric follower ids are normalized to integers', () {
      final state = LivestreamUserState.fromJson(<String, dynamic>{
        'user_id': 42,
        'followers_gained': <num>[1, 2.0, 3],
      });

      expect(state.followersGained, <int>[1, 2, 3]);
    });
  });
}
