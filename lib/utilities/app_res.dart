import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';

class AppRes {
  static String appName = 'TopTap';

  static String gifBrandName = 'GIPHY';

  // Common
  static String currency = '\$';
  static String hash = '#';
  static String equal = '=';
  static String slash = '/';

  // onBoardingScreen
  static int titleMaxLine = 2;
  static int descriptionMaxLine = 2;

  // For LiveStreaming values
  /// Time before the battle officially starts (in seconds)
  static const int battleStartInSecond = 10;

  /// Username of the official support account used by Help Center > Live Chat.
  /// Can be overridden from the admin panel (support_username setting).
  static const String supportUsername = 'toptapsupport';
  static const String supportEmail = 'support@toptap.app';

  /// Store subscription product ids that grant the verified badge. Create
  /// them in Google Play Console > Monetise > Subscriptions.
  static const List<String> verifiedBadgeProductIds = [
    'toptap_verified_monthly',
    'toptap_verified_yearly',
  ];

  /// Total duration of the battle (in minutes)
  static const int battleDurationInMinutes = 1;

  /// Duration to show the main view after battle ends (in seconds)
  static const int battleEndMainViewInSecond = 10;

  /// Cooldown duration after a battle ends.
  /// Please wait some time before starting a new battle. (in seconds)
  static const int battleCooldownDurationInSecond = 10;

  // Pagination limit
  static const int paginationLimit = 20;
  static const int chatPaginationLimit = 40;
  static const int paginationLimitDetectWord =
      5; // For mention user and hashtag

  // Profile image
  static const int compressQualityInKB =
      100; // This value kb (Example: 100 means 100kb)

  // Image Upload Quality
  static double maxWidth = 800;
  static double maxHeight = 800;
  static int imageQuality = 95; // ranging from 0-99

  // Create Feed limit
  static int imageLimit = 5;
  // Legacy compatibility value: keep aligned with longest selectable reel duration.
  static int maxVideoDuration = maxReelDuration; // In seconds

  // Pin Post and comment
  static const String postPinIcon = '📌';
  static const int maxPinFeed = 1;
  static const int maxPinComment = 1;

  // STORY
  static const int storyVideoDuration = 15; // IN SECOND
  static const int storyImageAndTextDuration = 5; // IN SECOND
  static const double minFontSize = 25;
  static const double maxFontSize = 50;
  static const List<int> storyDurations = [5, 10, 15]; // IN SECOND
  static const List<String> storyQuickReplyEmojis = [
    '😂',
    '😮',
    '😍',
    '😢',
    '👏',
    '🔥'
  ];

  // Reels
  static const int maxReelDuration = 600; // IN SECOND
  static const List<int> secondList = [15, 20, 30, 60, 120, 300, 600];
  static const String addMusicName = 'Original Audio';

  // Posts
  static const int trimLine = 5; // ReadMoreText

  // Request Withdrawal
  static const emptyGatewayMessage =
      'Please add Payment Gateway List in Admin Panel';

  static const emptyReportReason =
      'Please add Report Reason List in Admin Panel';

  // detectable RegExp
  static RegExp detectableReg =
      RegExp(r'[@#][\w.-]+'); // Detects @username or #hashtag
  static RegExp userNameRegex =
      RegExp(r'@([a-zA-Z0-9_.-]+)'); // Captures username without '@'
  static RegExp hashTagRegex =
      RegExp(r'#([\w.-]+)'); // Captures hashtag without '#'
  static RegExp urlRegex =
      RegExp(r'(?:(?:https?|ftp)://)?[\w/\-?=%.]+\.[\w/\-?=%.]+');
  static RegExp combinedRegex = RegExp(
    r'(@[a-zA-Z0-9_.-]+)|(#([\w.-]+))|((?:(?:https?|ftp)://)?[\w/\-?=%.]+\.[\w/\-?=%.]+)',
  );

  // Send Gift
  static const int giftDialogDismissTime = 2; // enter in second

  // Camera
  static const bool isDeepAR = false;

  // Chat
  static const int shareChatLimit = 5;

  // Play store link
  static const String whatsappPlayStoreLink =
      "https://play.google.com/store/apps/details?id=com.whatsapp&hl=en_IN";
  static const String instagramPlayStoreLink =
      "https://play.google.com/store/apps/details?id=com.instagram.android&hl=en_IN";
  static const String telegramPlayStoreLink =
      "https://play.google.com/store/apps/details?id=org.telegram.messenger&hl=en_IN";

  // Create Post
  // nearBySearch
  static const double nearBySearchRadius = 500.0;
  static const List<String> nearbySearchTypes = [
    "tourist_attraction",
    "cafe",
    "bar",
    "park",
    "shopping_mall",
    "gym",
    "restaurant"
  ]; // For more Type visit : https://developers.google.com/maps/documentation/places/web-service/place-types#table-a

  // Sight engine
  static const int sightEngineCropSec = 5;
}

enum TabType {
  discover,
  following,
  nearby;

  String get title {
    switch (this) {
      case TabType.discover:
        return LKey.discover.tr;
      case TabType.following:
        return LKey.following.tr;
      case TabType.nearby:
        return LKey.nearby.tr;
    }
  }
}
