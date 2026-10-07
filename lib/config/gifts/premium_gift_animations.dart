/// Cinematic full-screen reveal animations for the 16 real "Premium"
/// category `tbl_gifts` rows (ids 21-36, seeded 2026-10-08). `Gift` (see
/// `settings_model.dart`) has `name`/`category` but no animation field —
/// the catalog has no place to store a cinematic video URL, so that mapping
/// lives here, keyed by the gift's real backend id.
///
/// [videoUrl] points at the project VPS (http://194.164.151.34/gift_animations/),
/// not a bundled asset: these are multi-megabyte cinematic clips, and
/// bundling even a handful into every install would bloat the app for every
/// user whether or not they ever see these gifts.
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
    giftId: 21,
    name: 'Mech Titan',
    videoUrl: '$_giftAnimationBaseUrl/01_mech_titan.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 22,
    name: 'Mystic Rose',
    videoUrl: '$_giftAnimationBaseUrl/02_mystic_rose.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 23,
    name: 'Lucky Train',
    videoUrl: '$_giftAnimationBaseUrl/03_lucky_train.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 24,
    name: 'Celestial Unicorn',
    videoUrl: '$_giftAnimationBaseUrl/04_celestial_unicorn.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 25,
    name: 'Dream Castle',
    videoUrl: '$_giftAnimationBaseUrl/05_dream_castle.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 26,
    name: 'Inferno Phoenix',
    videoUrl: '$_giftAnimationBaseUrl/06_inferno_phoenix.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 27,
    name: 'Shadow Tiger',
    videoUrl: '$_giftAnimationBaseUrl/07_shadow_tiger.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 28,
    name: 'Thunder God',
    videoUrl: '$_giftAnimationBaseUrl/08_thunder_god.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 29,
    name: 'Sky Griffin Lion',
    videoUrl: '$_giftAnimationBaseUrl/09_sky_griffin_lion.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 30,
    name: 'King Leonardo',
    videoUrl: '$_giftAnimationBaseUrl/10_king_leonardo.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 31,
    name: 'Divine Light',
    videoUrl: '$_giftAnimationBaseUrl/11_divine_light.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 32,
    name: 'Guardian Angel',
    videoUrl: '$_giftAnimationBaseUrl/12_guardian_angel.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 33,
    name: 'Storm Eagle',
    videoUrl: '$_giftAnimationBaseUrl/13_storm_eagle.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 34,
    name: 'Street Magic',
    videoUrl: '$_giftAnimationBaseUrl/14_street_magic.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 35,
    name: 'Moon Wolf',
    videoUrl: '$_giftAnimationBaseUrl/15_moon_wolf.mp4',
  ),
  PremiumGiftAnimation(
    giftId: 36,
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
