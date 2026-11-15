import 'package:get/get.dart';
// 🔇 COMMENTED OUT PROBLEMATIC IMPORTS TO FIX AUDIO ISSUES
// import 'package:toptap/screen/playback_settings_screen/playback_settings_controller.dart';
// import 'package:toptap/screen/content_preferences_screen/content_preferences_controller.dart';
// import 'package:toptap/screen/accessibility_settings_screen/accessibility_settings_controller.dart';
import 'package:toptap/screen/settings_screen/notification_settings_screen/notification_settings_screen_controller.dart';
import 'package:toptap/screen/settings_screen/localization_screen/localization_screen_controller.dart';

/// Centralized service for accessing all app settings
/// This service provides easy access to settings across the entire app
class SettingsService extends GetxService {
  static SettingsService get instance =>
      Get.find<SettingsService>();

  // Controller getters - lazy initialization
  // 🔇 COMMENTING OUT PROBLEMATIC CONTROLLERS TO FIX APP STABILITY
  // PlaybackSettingsController get playback => Get.find<PlaybackSettingsController>();           // 🔇 DISABLED
  // ContentPreferencesController get content => Get.find<ContentPreferencesController>();         // 🔇 DISABLED
  // AccessibilitySettingsController get accessibility => Get.find<AccessibilitySettingsController>(); // 🔇 DISABLED
  NotificationSettingsScreenController get notifications =>
      Get.find<NotificationSettingsScreenController>();
  LocalizationScreenController get localization =>
      Get.find<LocalizationScreenController>();

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
  }

  /// Initialize all settings controllers with permanent storage
  void _initializeControllers() {
    try {
      // 🔇 COMMENTING OUT PROBLEMATIC CONTROLLERS TO FIX APP STABILITY
      // Initialize all settings controllers as permanent services
      // Get.put(PlaybackSettingsController(), permanent: true);         // 🔇 DISABLED
      // Get.put(ContentPreferencesController(), permanent: true);       // 🔇 DISABLED
      // Get.put(AccessibilitySettingsController(), permanent: true);    // 🔇 DISABLED
      Get.put(NotificationSettingsScreenController(),
          permanent: true);
      Get.put(LocalizationScreenController(),
          permanent: true);

      print(
          '✅ SettingsService: Essential controllers initialized (accessibility/playback/content DISABLED)');
    } catch (e) {
      print(
          '❌ SettingsService: Error initializing controllers: $e');
    }
  }

  // =============================================================================
  // QUICK ACCESS METHODS FOR VIDEO PLAYBACK - 🔇 DISABLED TO FIX AUDIO ISSUES
  // =============================================================================

  /*
  /// Whether videos should auto-play when visible
  bool get shouldAutoPlay => playback.autoPlayVideos.value;
  
  /// Whether videos should play with sound on autoplay
  bool get shouldPlayWithSound => playback.autoPlayWithSound.value;
  
  /// Whether videos should loop continuously
  bool get shouldLoop => playback.loopVideos.value;
  
  /// Whether to show playback speed controls
  bool get showSpeedControl => playback.showPlaybackSpeedControl.value;
  
  /// Preferred video quality setting
  VideoQuality get preferredQuality => playback.videoQuality.value;
  
  /// Whether data saver mode is enabled
  bool get dataSaverEnabled => playback.dataSaverMode.value;
  
  /// Whether to use WiFi only for HD content
  bool get wifiOnlyHD => playback.wifiOnlyHD.value;
  
  /// Whether to automatically show captions
  bool get autoShowCaptions => playback.autoShowCaptions.value;
  
  /// Caption size preference
  CaptionSize get captionSize => playback.captionSize.value;
  
  /// Whether hardware acceleration is enabled
  bool get hardwareAcceleration => playback.hardwareAcceleration.value;
  
  /// Whether to preload next video
  bool get preloadNextVideo => playback.preloadNextVideo.value;
  
  /// Whether to reduce loud sounds
  bool get reduceLoudSounds => playback.reduceLoudSounds.value;
  */

  // =============================================================================
  // QUICK ACCESS METHODS FOR CONTENT PREFERENCES - 🔇 DISABLED TO FIX AUDIO ISSUES
  // =============================================================================

  /*
  /// Whether to hide sensitive content
  bool get hideSensitiveContent => content.hideSensitiveContent.value;
  
  /// Whether to filter inappropriate comments
  bool get filterInappropriateComments => content.filterInappropriateComments.value;
  
  /// Whether to auto-mute videos
  bool get autoMuteVideos => content.autoMuteVideos.value;
  
  /// Whether personalized recommendations are enabled
  bool get personalizedRecommendations => content.personalizedRecommendations.value;
  
  /// Whether to show regional content
  bool get showRegionalContent => content.showRegionalContent.value;
  
  /// Whether to show trending content
  bool get showTrendingContent => content.showTrendingContent.value;
  
  /// Whether to show music videos
  bool get showMusicVideos => content.showMusicVideos.value;
  
  /// Whether to show gaming content
  bool get showGamingContent => content.showGamingContent.value;
  
  /// Whether to show educational content
  bool get showEducationalContent => content.showEducationalContent.value;
  
  /// Current restricted mode setting
  String get restrictedMode => content.restrictedMode.value;
  */

  // =============================================================================
  // QUICK ACCESS METHODS FOR ACCESSIBILITY - 🔇 DISABLED TO FIX AUDIO ISSUES
  // =============================================================================

  /*
  /// Whether high contrast mode is enabled
  bool get highContrastMode => accessibility.highContrastMode.value;
  
  /// Whether large text size is enabled
  bool get largeTextSize => accessibility.largeTextSize.value;
  
  /// Current font size setting
  FontSize get fontSize => accessibility.fontSize.value;
  
  /// Whether bold text is enabled
  bool get boldText => accessibility.boldText.value;
  
  /// Whether screen reader is enabled
  bool get screenReaderEnabled => accessibility.screenReaderEnabled.value;
  
  /// Screen reader speed setting
  ScreenReaderSpeed get screenReaderSpeed => accessibility.screenReaderSpeed.value;
  */

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Get volume level - COMPLETELY SIMPLIFIED TO FIX AUDIO ISSUES
  double getVideoVolume() {
    return 1.0; // � DISABLED ALL ACCESSIBILITY LOGIC - JUST RETURN FULL VOLUME
  }

  /// Get volume specifically for reels - COMPLETELY SIMPLIFIED
  double getReelVolume() {
    return 1.0; // 🔇 DISABLED ALL ACCESSIBILITY LOGIC - JUST RETURN FULL VOLUME
  }

  /*
  /// Check if content should be shown based on filtering settings
  bool shouldShowContent({
    bool? isSensitive,
    bool? hasExplicitContent,
    bool? isMusicVideo,
    bool? isGamingContent,
    bool? isEducational,
    List<String>? tags,
  }) {
    // Check sensitive content filter
    if (hideSensitiveContent && (isSensitive == true)) {
      return false;
    }
    
    // Check restricted mode
    if (restrictedMode == 'Strict' && (hasExplicitContent == true)) {
      return false;
    }
    
    // Check content type preferences
    if (isMusicVideo == true && !showMusicVideos) {
      return false;
    }
    
    if (isGamingContent == true && !showGamingContent) {
      return false;
    }
    
    if (isEducational == true && !showEducationalContent) {
      return false;
    }
    
    return true;
  }
  
  /// Get font size in pixels based on accessibility settings
  double getFontSizeInPixels() {
    double baseSize = 16.0;
    
    // Apply font size setting
    switch (fontSize) {
      case FontSize.small:
        baseSize = 14.0;
        break;
      case FontSize.medium:
        baseSize = 16.0;
        break;
      case FontSize.large:
        baseSize = 20.0;
        break;
      case FontSize.extraLarge:
        baseSize = 24.0;
        break;
    }
    
    // Apply large text size multiplier if enabled
    if (largeTextSize) {
      baseSize *= 1.3;
    }
    
    return baseSize;
  }
  
  /// Check if content filtering is active
  bool get hasActiveContentFiltering {
    return hideSensitiveContent || 
           filterInappropriateComments || 
           restrictedMode != 'Off';
  }
  
  /// Check if any accessibility features are enabled - 🔇 DISABLED TO FIX FREEZING
  bool get hasAccessibilityFeaturesEnabled {
    return false; // 🔇 ALL ACCESSIBILITY FEATURES DISABLED TO FIX APP FREEZING
    // Original logic tried to access disabled accessibility controller causing crashes:
    // return highContrastMode || largeTextSize || boldText || screenReaderEnabled || fontSize != FontSize.medium;
  }
  
  /// Get settings summary for debugging
  /// Get settings summary for debugging - 🔇 SIMPLIFIED TO FIX FREEZING
  Map<String, dynamic> getSettingsSummary() {
    return {
      'playback': {
        'autoPlay': shouldAutoPlay,
        'playWithSound': shouldPlayWithSound,
        'loop': shouldLoop,
        'quality': preferredQuality.name,
        'dataSaver': dataSaverEnabled,
      },
      'content': {
        'hideSensitive': hideSensitiveContent,
        'filterComments': filterInappropriateComments,
        'restrictedMode': restrictedMode,
        'showMusic': showMusicVideos,
        'showGaming': showGamingContent,
        'showEducational': showEducationalContent,
      },
      'accessibility': {
        'status': 'DISABLED - All accessibility features disabled to fix app freezing',
        'highContrast': false, // 🔇 FIXED: was calling disabled highContrastMode getter
        'largeText': false,    // 🔇 FIXED: was calling disabled largeTextSize getter
        'boldText': false,     // 🔇 FIXED: was calling disabled boldText getter
        'screenReader': false, // 🔇 FIXED: was calling disabled screenReaderEnabled getter
        'fontSize': 'medium',  // 🔇 FIXED: was calling disabled fontSize getter
      },
    };
  }
  */

  // 🔇 ALL ACCESSIBILITY, PLAYBACK, AND CONTENT METHODS DISABLED TO FIX AUDIO ISSUES
  // This is a simplified SettingsService that only handles volume calculation
  // All complex settings logic has been commented out to prevent app crashes and audio problems
}

// 🔇 END OF SIMPLIFIED SETTINGS SERVICE
