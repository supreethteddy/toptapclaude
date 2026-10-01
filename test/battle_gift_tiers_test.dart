import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/config/gifts/battle_gift_tiers.dart';

void main() {
  group('battlePointsForGift', () {
    test('a tiered gift is worth its configured points, not its coin price',
        () {
      // Galaxy (giftId -4 in the table) is worth 1000 points regardless of
      // whatever its real coin price ends up being set to.
      expect(battlePointsForGift(-4, fallbackCoins: 1), 1000);
      expect(battlePointsForGift(-4, fallbackCoins: 999), 1000);
    });

    test('the real backend gift (id 18) maps to Rose at 1 point', () {
      expect(battlePointsForGift(18, fallbackCoins: 1), 1);
    });

    test('an untiered gift falls back to its coin price 1:1', () {
      expect(battlePointsForGift(999999, fallbackCoins: 7), 7);
    });

    test('a null gift id falls back to the given coins', () {
      expect(battlePointsForGift(null, fallbackCoins: 3), 3);
    });

    test('every configured tier has a positive point value', () {
      for (final tier in battleGiftTiers) {
        expect(tier.points, greaterThan(0),
            reason: '${tier.label} must be worth at least 1 point');
      }
    });

    test('tier ids are unique — no gift accidentally mapped twice', () {
      final ids = battleGiftTiers.map((t) => t.giftId).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
