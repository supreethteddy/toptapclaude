/// Cinematic full-screen reveal animations for premium gifts, keyed by
/// backend gift id — same pattern and placeholder-id convention as
/// `battle_gift_tiers.dart` (negative ids = not a real `tbl_gifts` row yet).
/// The real `Gift` model (see `settings_model.dart`) has no `name` or
/// animation field at all, so both live here until real catalogue rows
/// exist.
///
/// [videoUrl] is deliberately a network URL, not a bundled asset: these are
/// multi-megabyte cinematic clips (see
/// /Users/supreeth/Newtoptap/gift_animations_processed on the dev machine),
/// and bundling even a handful into every install would bloat the app for
/// every user whether or not they ever see these gifts. They're meant to be
/// hosted on the project VPS and swapped in here by URL — every entry below
/// is a placeholder (empty string) until that upload happens, which is why
/// [premiumAnimationForGift] always returns an entry with a usable [name]
/// but callers must treat an empty [videoUrl] as "not ready to play yet".
class PremiumGiftAnimation {
  final int giftId;
  final String name;
  final String videoUrl;

  const PremiumGiftAnimation({
    required this.giftId,
    required this.name,
    required this.videoUrl,
  });

  bool get hasVideo => videoUrl.isNotEmpty;
}

const List<PremiumGiftAnimation> premiumGiftAnimations = [
  PremiumGiftAnimation(giftId: -101, name: 'Mech Titan', videoUrl: ''),
  PremiumGiftAnimation(giftId: -102, name: 'Mystic Rose', videoUrl: ''),
  PremiumGiftAnimation(giftId: -103, name: 'Lucky Train', videoUrl: ''),
  PremiumGiftAnimation(giftId: -104, name: 'Celestial Unicorn', videoUrl: ''),
  PremiumGiftAnimation(giftId: -105, name: 'Dream Castle', videoUrl: ''),
  PremiumGiftAnimation(giftId: -106, name: 'Inferno Phoenix', videoUrl: ''),
  PremiumGiftAnimation(giftId: -107, name: 'Shadow Tiger', videoUrl: ''),
  PremiumGiftAnimation(giftId: -108, name: 'Thunder God', videoUrl: ''),
  PremiumGiftAnimation(giftId: -109, name: 'Sky Griffin Lion', videoUrl: ''),
  PremiumGiftAnimation(giftId: -110, name: 'King Leonardo', videoUrl: ''),
  PremiumGiftAnimation(giftId: -111, name: 'Divine Light', videoUrl: ''),
  PremiumGiftAnimation(giftId: -112, name: 'Guardian Angel', videoUrl: ''),
  PremiumGiftAnimation(giftId: -113, name: 'Storm Eagle', videoUrl: ''),
  PremiumGiftAnimation(giftId: -114, name: 'Street Magic', videoUrl: ''),
  PremiumGiftAnimation(giftId: -115, name: 'Moon Wolf', videoUrl: ''),
  PremiumGiftAnimation(giftId: -116, name: 'Crimson Dragon', videoUrl: ''),
];

/// The reveal entry for this gift id, or null if it's a plain gift with no
/// big-screen animation (the existing static-image-in-chat treatment).
PremiumGiftAnimation? premiumAnimationForGift(int? giftId) {
  if (giftId == null) return null;
  for (final entry in premiumGiftAnimations) {
    if (entry.giftId == giftId) return entry;
  }
  return null;
}
