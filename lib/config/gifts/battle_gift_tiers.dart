/// Configurable gift-to-points table for LIVE PK Battle scoring.
///
/// The real `Gift` model (see `settings_model.dart`) only carries `id`,
/// `coinPrice`, and `image` — confirmed against the live backend database
/// too (`tbl_gifts` has no points/multiplier column). There's nowhere to
/// store "this gift is worth N battle points" except here, locally, same
/// pattern as `local_deepar_filters.dart`'s bundled filter registry.
///
/// Lookup is by the real backend gift id, so once/if the backend catalogue
/// grows beyond its current single entry, mapping a new real gift to a
/// tier here is a one-line change. Any gift NOT in this table still scores
/// in battle at the existing 1-coin-equals-1-point rate (see
/// `LivestreamScreenController.battlePointsForGift`) — this table only
/// overrides specific gifts, it doesn't gate which gifts are battle-eligible.
class BattleGiftTier {
  final int giftId;
  final String label;
  final String icon;
  final int points;

  const BattleGiftTier({
    required this.giftId,
    required this.label,
    required this.icon,
    required this.points,
  });
}

/// Backend gift id 18 (the one real gift on this backend at the time this
/// was written) is mapped to "Rose" as a concrete example tier. The other
/// three (Heart/Coffee/Galaxy) are ready to attach to real gift ids as soon
/// as the admin catalogue has more than one gift — ids -2/-3/-4 are
/// placeholders (negative, matching the convention in
/// local_deepar_filters.dart for "local-only, not a real backend id") so
/// they don't collide with a future real id and are easy to spot as
/// not-yet-wired.
const List<BattleGiftTier> battleGiftTiers = [
  BattleGiftTier(
    giftId: 18,
    label: 'Rose',
    icon: 'assets/gifts/battle_tiers/rose.png',
    points: 1,
  ),
  BattleGiftTier(
    giftId: -2,
    label: 'Heart',
    icon: 'assets/gifts/battle_tiers/heart.png',
    points: 5,
  ),
  BattleGiftTier(
    giftId: -3,
    label: 'Coffee',
    icon: 'assets/gifts/battle_tiers/coffee.png',
    points: 10,
  ),
  BattleGiftTier(
    giftId: -4,
    label: 'Galaxy',
    icon: 'assets/gifts/battle_tiers/galaxy.png',
    points: 1000,
  ),
];

/// Points this gift is worth in a PK Battle. Falls back to [fallbackCoins]
/// (the gift's own coin price, i.e. the pre-existing 1-coin-equals-1-point
/// behavior) for any gift id not in [battleGiftTiers], so battles never
/// silently award zero points for a real, paid-for gift just because it
/// hasn't been mapped to a tier yet.
int battlePointsForGift(int? giftId, {required int fallbackCoins}) {
  if (giftId == null) return fallbackCoins;
  for (final tier in battleGiftTiers) {
    if (tier.giftId == giftId) return tier.points;
  }
  return fallbackCoins;
}
