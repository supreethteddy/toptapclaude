import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:toptap/common/controller/base_controller.dart';

enum FontSize {
  small,
  medium,
  large,
  extraLarge;

  String get title {
    switch (this) {
      case FontSize.small:
        return 'Small';
      case FontSize.medium:
        return 'Medium';
      case FontSize.large:
        return 'Large';
      case FontSize.extraLarge:
        return 'Extra Large';
    }
  }
}

enum ScreenReaderSpeed {
  slow,
  normal,
  fast,
  veryFast;

  String get title {
    switch (this) {
      case ScreenReaderSpeed.slow:
        return 'Slow';
      case ScreenReaderSpeed.normal:
        return 'Normal';
      case ScreenReaderSpeed.fast:
        return 'Fast';
      case ScreenReaderSpeed.veryFast:
        return 'Very Fast';
    }
  }
}

class AccessibilitySettingsController extends BaseController {
  final _storage = GetStorage();
  
  // Vision Settings
  RxBool highContrastMode = false.obs;
  RxBool largeTextSize = false.obs;
  Rx<FontSize> fontSize = FontSize.medium.obs;
  RxBool boldText = false.obs;
  
  // Motor Settings
  RxBool touchAccommodations = false.obs;
  RxBool vibrationFeedback = true.obs;
  
  // Audio Settings
  RxBool audioDescriptions = false.obs;
  RxBool monoAudio = false.obs;
  
  // Navigation Settings
  RxBool voiceControl = false.obs;
  RxBool easySwipeNavigation = false.obs;
  
  // Screen Reader
  RxBool screenReaderEnabled = false.obs;
  Rx<ScreenReaderSpeed> screenReaderSpeed = ScreenReaderSpeed.normal.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }
  
  void loadSettings() {
    // Load settings from GetStorage
    highContrastMode.value = _storage.read('highContrastMode') ?? false;
    largeTextSize.value = _storage.read('largeTextSize') ?? false;
    
    String fontSizeString = _storage.read('fontSize') ?? 'medium';
    fontSize.value = FontSize.values.firstWhere(
      (e) => e.name == fontSizeString,
      orElse: () => FontSize.medium,
    );
    
    boldText.value = _storage.read('boldText') ?? false;
    touchAccommodations.value = _storage.read('touchAccommodations') ?? false;
    vibrationFeedback.value = _storage.read('vibrationFeedback') ?? true;
    audioDescriptions.value = _storage.read('audioDescriptions') ?? false;
    monoAudio.value = _storage.read('monoAudio') ?? false;
    voiceControl.value = _storage.read('voiceControl') ?? false;
    easySwipeNavigation.value = _storage.read('easySwipeNavigation') ?? false;
    screenReaderEnabled.value = _storage.read('screenReaderEnabled') ?? false;
    
    String screenReaderSpeedString = _storage.read('screenReaderSpeed') ?? 'normal';
    screenReaderSpeed.value = ScreenReaderSpeed.values.firstWhere(
      (e) => e.name == screenReaderSpeedString,
      orElse: () => ScreenReaderSpeed.normal,
    );
  }
  
  void saveSetting(String key, dynamic value) {
    _storage.write(key, value);
  }
  
  // Vision Settings Methods
  void toggleHighContrastMode(bool value) {
    highContrastMode.value = value;
    saveSetting('highContrastMode', value);
  }
  
  void toggleLargeTextSize(bool value) {
    largeTextSize.value = value;
    saveSetting('largeTextSize', value);
  }
  
  void setFontSize(FontSize? size) {
    if (size != null) {
      fontSize.value = size;
      saveSetting('fontSize', size.name);
    }
  }
  
  void toggleBoldText(bool value) {
    boldText.value = value;
    saveSetting('boldText', value);
  }
  
  // Motor Settings Methods
  void toggleTouchAccommodations(bool value) {
    touchAccommodations.value = value;
    saveSetting('touchAccommodations', value);
  }
  
  void toggleVibrationFeedback(bool value) {
    vibrationFeedback.value = value;
    saveSetting('vibrationFeedback', value);
  }
  
  // Audio Settings Methods
  void toggleAudioDescriptions(bool value) {
    audioDescriptions.value = value;
    saveSetting('audioDescriptions', value);
  }
  
  void toggleMonoAudio(bool value) {
    monoAudio.value = value;
    saveSetting('monoAudio', value);
  }
  
  // Navigation Settings Methods
  void toggleVoiceControl(bool value) {
    voiceControl.value = value;
    saveSetting('voiceControl', value);
  }
  
  void toggleEasySwipeNavigation(bool value) {
    easySwipeNavigation.value = value;
    saveSetting('easySwipeNavigation', value);
  }
  
  // Screen Reader Methods
  void toggleScreenReader(bool value) {
    screenReaderEnabled.value = value;
    saveSetting('screenReaderEnabled', value);
  }
  
  void setScreenReaderSpeed(ScreenReaderSpeed? speed) {
    if (speed != null) {
      screenReaderSpeed.value = speed;
      saveSetting('screenReaderSpeed', speed.name);
    }
  }
  
  // Reset to defaults
  void resetToDefaults() {
    highContrastMode.value = false;
    largeTextSize.value = false;
    fontSize.value = FontSize.medium;
    boldText.value = false;
    touchAccommodations.value = false;
    vibrationFeedback.value = true;
    audioDescriptions.value = false;
    monoAudio.value = false;
    voiceControl.value = false;
    easySwipeNavigation.value = false;
    screenReaderEnabled.value = false;
    screenReaderSpeed.value = ScreenReaderSpeed.normal;
    
    // Save all defaults
    saveSetting('highContrastMode', false);
    saveSetting('largeTextSize', false);
    saveSetting('fontSize', FontSize.medium.name);
    saveSetting('boldText', false);
    saveSetting('touchAccommodations', false);
    saveSetting('vibrationFeedback', true);
    saveSetting('audioDescriptions', false);
    saveSetting('monoAudio', false);
    saveSetting('voiceControl', false);
    saveSetting('easySwipeNavigation', false);
    saveSetting('screenReaderEnabled', false);
    saveSetting('screenReaderSpeed', ScreenReaderSpeed.normal.name);
  }
}
