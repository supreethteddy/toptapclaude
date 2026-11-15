import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:toptap/common/controller/base_controller.dart';

class ContentPreferencesController extends BaseController {
  final _storage = GetStorage();
  
  // Content Filtering
  RxBool hideSensitiveContent = false.obs;
  RxBool filterInappropriateComments = false.obs;
  RxBool autoMuteVideos = false.obs;
  
  // Content Discovery
  RxBool personalizedRecommendations = true.obs;
  RxBool showRegionalContent = false.obs;
  RxBool showTrendingContent = true.obs;
  
  // Content Types
  RxBool showMusicVideos = true.obs;
  RxBool showGamingContent = true.obs;
  RxBool showEducationalContent = true.obs;
  
  // Age-Appropriate Content
  RxString restrictedMode = 'Off'.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadPreferences();
  }
  
  void loadPreferences() {
    // Load preferences from GetStorage
    hideSensitiveContent.value = _storage.read('hideSensitiveContent') ?? false;
    filterInappropriateComments.value = _storage.read('filterInappropriateComments') ?? false;
    autoMuteVideos.value = _storage.read('autoMuteVideos') ?? false;
    personalizedRecommendations.value = _storage.read('personalizedRecommendations') ?? true;
    showRegionalContent.value = _storage.read('showRegionalContent') ?? false;
    showTrendingContent.value = _storage.read('showTrendingContent') ?? true;
    showMusicVideos.value = _storage.read('showMusicVideos') ?? true;
    showGamingContent.value = _storage.read('showGamingContent') ?? true;
    showEducationalContent.value = _storage.read('showEducationalContent') ?? true;
    restrictedMode.value = _storage.read('restrictedMode') ?? 'Off';
  }
  
  void savePreference(String key, bool value) {
    _storage.write(key, value);
  }
  
  void savePreferenceString(String key, String value) {
    _storage.write(key, value);
  }
  
  // Content Filtering Methods
  void toggleSensitiveContent(bool value) {
    hideSensitiveContent.value = value;
    savePreference('hideSensitiveContent', value);
  }
  
  void toggleInappropriateComments(bool value) {
    filterInappropriateComments.value = value;
    savePreference('filterInappropriateComments', value);
  }
  
  void toggleAutoMuteVideos(bool value) {
    autoMuteVideos.value = value;
    savePreference('autoMuteVideos', value);
  }
  
  // Content Discovery Methods
  void togglePersonalizedRecommendations(bool value) {
    personalizedRecommendations.value = value;
    savePreference('personalizedRecommendations', value);
  }
  
  void toggleRegionalContent(bool value) {
    showRegionalContent.value = value;
    savePreference('showRegionalContent', value);
  }
  
  void toggleTrendingContent(bool value) {
    showTrendingContent.value = value;
    savePreference('showTrendingContent', value);
  }
  
  // Content Types Methods
  void toggleMusicVideos(bool value) {
    showMusicVideos.value = value;
    savePreference('showMusicVideos', value);
  }
  
  void toggleGamingContent(bool value) {
    showGamingContent.value = value;
    savePreference('showGamingContent', value);
  }
  
  void toggleEducationalContent(bool value) {
    showEducationalContent.value = value;
    savePreference('showEducationalContent', value);
  }
  
  // Restricted Mode
  void setRestrictedMode(String mode) {
    restrictedMode.value = mode;
    savePreferenceString('restrictedMode', mode);
  }
  
  // Reset to defaults
  void resetToDefaults() {
    hideSensitiveContent.value = false;
    filterInappropriateComments.value = false;
    autoMuteVideos.value = false;
    personalizedRecommendations.value = true;
    showRegionalContent.value = false;
    showTrendingContent.value = true;
    showMusicVideos.value = true;
    showGamingContent.value = true;
    showEducationalContent.value = true;
    restrictedMode.value = 'Off';
    
    // Save all defaults
    savePreference('hideSensitiveContent', false);
    savePreference('filterInappropriateComments', false);
    savePreference('autoMuteVideos', false);
    savePreference('personalizedRecommendations', true);
    savePreference('showRegionalContent', false);
    savePreference('showTrendingContent', true);
    savePreference('showMusicVideos', true);
    savePreference('showGamingContent', true);
    savePreference('showEducationalContent', true);
    savePreferenceString('restrictedMode', 'Off');
  }
}
