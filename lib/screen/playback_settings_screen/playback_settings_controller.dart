import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:toptap/common/controller/base_controller.dart';

enum VideoQuality {
  auto,
  low,
  medium,
  high,
  ultra;

  String get title {
    switch (this) {
      case VideoQuality.auto:
        return 'Auto';
      case VideoQuality.low:
        return 'Low (360p)';
      case VideoQuality.medium:
        return 'Medium (720p)';
      case VideoQuality.high:
        return 'High (1080p)';
      case VideoQuality.ultra:
        return 'Ultra (4K)';
    }
  }
}

enum CaptionSize {
  small,
  medium,
  large,
  extraLarge;

  String get title {
    switch (this) {
      case CaptionSize.small:
        return 'Small';
      case CaptionSize.medium:
        return 'Medium';
      case CaptionSize.large:
        return 'Large';
      case CaptionSize.extraLarge:
        return 'Extra Large';
    }
  }
}

class PlaybackSettingsController extends BaseController {
  final _storage = GetStorage();

  // Video Quality
  Rx<VideoQuality> videoQuality = VideoQuality.auto.obs;
  RxBool autoQuality = true.obs;

  // Audio Settings
  RxBool autoPlayWithSound =
      true.obs; // 🎵 Changed default to true for audio
  RxBool reduceLoudSounds = false.obs;

  // Playback Controls
  RxBool autoPlayVideos = true.obs;
  RxBool loopVideos = false.obs;
  RxBool showPlaybackSpeedControl = false.obs;

  // Data Usage
  RxBool dataSaverMode = false.obs;
  RxBool wifiOnlyHD = false.obs;

  // Subtitles & Captions
  RxBool autoShowCaptions = false.obs;
  Rx<CaptionSize> captionSize = CaptionSize.medium.obs;

  // Performance
  RxBool hardwareAcceleration = true.obs;
  RxBool preloadNextVideo = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  void loadSettings() {
    // Load settings from GetStorage
    String videoQualityString =
        _storage.read('videoQuality') ?? 'auto';
    videoQuality.value = VideoQuality.values.firstWhere(
      (e) => e.name == videoQualityString,
      orElse: () => VideoQuality.auto,
    );

    autoQuality.value =
        _storage.read('autoQuality') ?? true;
    autoPlayWithSound.value =
        _storage.read('autoPlayWithSound') ??
            true; // 🎵 Changed default to true for audio
    reduceLoudSounds.value =
        _storage.read('reduceLoudSounds') ?? false;
    autoPlayVideos.value =
        _storage.read('autoPlayVideos') ?? true;
    loopVideos.value = _storage.read('loopVideos') ?? false;
    showPlaybackSpeedControl.value =
        _storage.read('showPlaybackSpeedControl') ?? false;
    dataSaverMode.value =
        _storage.read('dataSaverMode') ?? false;
    wifiOnlyHD.value = _storage.read('wifiOnlyHD') ?? false;
    autoShowCaptions.value =
        _storage.read('autoShowCaptions') ?? false;

    String captionSizeString =
        _storage.read('captionSize') ?? 'medium';
    captionSize.value = CaptionSize.values.firstWhere(
      (e) => e.name == captionSizeString,
      orElse: () => CaptionSize.medium,
    );

    hardwareAcceleration.value =
        _storage.read('hardwareAcceleration') ?? true;
    preloadNextVideo.value =
        _storage.read('preloadNextVideo') ?? true;
  }

  void saveSetting(String key, dynamic value) {
    _storage.write(key, value);
  }

  // Video Quality Methods
  void setVideoQuality(VideoQuality? quality) {
    if (quality != null) {
      videoQuality.value = quality;
      saveSetting('videoQuality', quality.name);
    }
  }

  void toggleAutoQuality(bool value) {
    autoQuality.value = value;
    saveSetting('autoQuality', value);
  }

  // Audio Settings Methods
  void toggleAutoPlayWithSound(bool value) {
    autoPlayWithSound.value = value;
    saveSetting('autoPlayWithSound', value);
  }

  void toggleReduceLoudSounds(bool value) {
    reduceLoudSounds.value = value;
    saveSetting('reduceLoudSounds', value);
  }

  // Playback Controls Methods
  void toggleAutoPlayVideos(bool value) {
    autoPlayVideos.value = value;
    saveSetting('autoPlayVideos', value);
  }

  void toggleLoopVideos(bool value) {
    loopVideos.value = value;
    saveSetting('loopVideos', value);
  }

  void toggleShowPlaybackSpeedControl(bool value) {
    showPlaybackSpeedControl.value = value;
    saveSetting('showPlaybackSpeedControl', value);
  }

  // Data Usage Methods
  void toggleDataSaverMode(bool value) {
    dataSaverMode.value = value;
    saveSetting('dataSaverMode', value);
  }

  void toggleWifiOnlyHD(bool value) {
    wifiOnlyHD.value = value;
    saveSetting('wifiOnlyHD', value);
  }

  // Subtitles & Captions Methods
  void toggleAutoShowCaptions(bool value) {
    autoShowCaptions.value = value;
    saveSetting('autoShowCaptions', value);
  }

  void setCaptionSize(CaptionSize? size) {
    if (size != null) {
      captionSize.value = size;
      saveSetting('captionSize', size.name);
    }
  }

  // Performance Methods
  void toggleHardwareAcceleration(bool value) {
    hardwareAcceleration.value = value;
    saveSetting('hardwareAcceleration', value);
  }

  void togglePreloadNextVideo(bool value) {
    preloadNextVideo.value = value;
    saveSetting('preloadNextVideo', value);
  }

  // Reset to defaults
  void resetToDefaults() {
    videoQuality.value = VideoQuality.auto;
    autoQuality.value = true;
    autoPlayWithSound.value =
        true; // 🎵 Changed default to true for audio
    reduceLoudSounds.value = false;
    autoPlayVideos.value = true;
    loopVideos.value = false;
    showPlaybackSpeedControl.value = false;
    dataSaverMode.value = false;
    wifiOnlyHD.value = false;
    autoShowCaptions.value = false;
    captionSize.value = CaptionSize.medium;
    hardwareAcceleration.value = true;
    preloadNextVideo.value = true;

    // Save all defaults
    saveSetting('videoQuality', VideoQuality.auto.name);
    saveSetting('autoQuality', true);
    saveSetting('autoPlayWithSound', false);
    saveSetting('reduceLoudSounds', false);
    saveSetting('autoPlayVideos', true);
    saveSetting('loopVideos', false);
    saveSetting('showPlaybackSpeedControl', false);
    saveSetting('dataSaverMode', false);
    saveSetting('wifiOnlyHD', false);
    saveSetting('autoShowCaptions', false);
    saveSetting('captionSize', CaptionSize.medium.name);
    saveSetting('hardwareAcceleration', true);
    saveSetting('preloadNextVideo', true);
  }
}
