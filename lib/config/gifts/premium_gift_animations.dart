/// Cinematic full-screen reveal animations for premium gifts, keyed by
/// backend gift id — same pattern and placeholder-id convention as
/// `battle_gift_tiers.dart` (negative ids = not a real `tbl_gifts` row yet).
/// The real `Gift` model (see `settings_model.dart`) has no `name` or
/// animation field at all, so both live here until real catalogue rows
/// exist.
///
/// [videoUrl] points at the project VPS (http://194.164.151.34/gift_animations/),
/// not a bundled asset: these are multi-megabyte cinematic clips, and
/// bundling even a handful into every install would bloat the app for every
/// user whether or not they ever see these gifts. The ids, names, and video
/// choices below are all still placeholders pending the client's real gift
/// catalogue decisions (names, prices, which ones are standalone vs. part of
/// a Vault-style random reveal) — only the hosting is real.
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

const String _giftAnimationBaseUrl =
    'http://194.164.151.34/gift_animations';

const List<PremiumGiftAnimation> premiumGiftAnimations = [
  PremiumGiftAnimation(
    giftId: -101,
    name: 'Mech Titan',
    videoUrl: '$_giftAnimationBaseUrl/01_mech_titan.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -102,
    name: 'Mystic Rose',
    videoUrl: '$_giftAnimationBaseUrl/02_mystic_rose.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -103,
    name: 'Lucky Train',
    videoUrl: '$_giftAnimationBaseUrl/03_lucky_train.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -104,
    name: 'Celestial Unicorn',
    videoUrl: '$_giftAnimationBaseUrl/04_celestial_unicorn.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -105,
    name: 'Dream Castle',
    videoUrl: '$_giftAnimationBaseUrl/05_dream_castle.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -106,
    name: 'Inferno Phoenix',
    videoUrl: '$_giftAnimationBaseUrl/06_inferno_phoenix.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -107,
    name: 'Shadow Tiger',
    videoUrl: '$_giftAnimationBaseUrl/07_shadow_tiger.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -108,
    name: 'Thunder God',
    videoUrl: '$_giftAnimationBaseUrl/08_thunder_god.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -109,
    name: 'Sky Griffin Lion',
    videoUrl: '$_giftAnimationBaseUrl/09_sky_griffin_lion.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -110,
    name: 'King Leonardo',
    videoUrl: '$_giftAnimationBaseUrl/10_king_leonardo.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -111,
    name: 'Divine Light',
    videoUrl: '$_giftAnimationBaseUrl/11_divine_light.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -112,
    name: 'Guardian Angel',
    videoUrl: '$_giftAnimationBaseUrl/12_guardian_angel.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -113,
    name: 'Storm Eagle',
    videoUrl: '$_giftAnimationBaseUrl/13_storm_eagle.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -114,
    name: 'Street Magic',
    videoUrl: '$_giftAnimationBaseUrl/14_street_magic.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -115,
    name: 'Moon Wolf',
    videoUrl: '$_giftAnimationBaseUrl/15_moon_wolf.mp4',
  ),
  PremiumGiftAnimation(
    giftId: -116,
    name: 'Crimson Dragon',
    videoUrl: '$_giftAnimationBaseUrl/16_crimson_dragon.mp4',
  ),
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
