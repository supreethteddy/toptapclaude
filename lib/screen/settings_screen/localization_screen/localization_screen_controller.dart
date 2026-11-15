import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/utils/settings_error_handler.dart';
import 'package:toptap/model/general/settings_model.dart';

class LocalizationScreenController extends GetxController {
  RxList<Language> languages = <Language>[].obs;
  RxString selectedLanguageCode = 'en'.obs;
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLanguages();
    _loadSelectedLanguage();
  }

  // Load available languages from settings
  void _loadLanguages() async {
    try {
      isLoading.value = true;
      
      // Get languages from settings model or use default languages
      final availableLanguages = _getDefaultLanguages();
      
      languages.value = availableLanguages;
      
      // Sort languages alphabetically by localized title
      languages.sort((a, b) {
        final aTitle = a.localizedTitle ?? a.title ?? '';
        final bTitle = b.localizedTitle ?? b.title ?? '';
        return aTitle.compareTo(bTitle);
      });
      
    } catch (e) {
      print('Error loading languages: \$e');
      SettingsErrorHandler.handleError(e, customMessage: 'Failed to load languages'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  // Load currently selected language
  void _loadSelectedLanguage() {
    try {
      final storage = SessionManager.instance.storage;
      selectedLanguageCode.value = storage.read('selected_language') ?? 'en';
    } catch (e) {
      print('Error loading selected language: \$e');
      selectedLanguageCode.value = 'en';
      SettingsErrorHandler.handleError(e, customMessage: 'Failed to load language preference'.tr);
    }
  }

  // Select a language
  void selectLanguage(Language language) async {
    try {
      if (language.code == null) {
        SettingsErrorHandler.showErrorSnackbar('Invalid language selection'.tr);
        return;
      }

      // Update selected language
      selectedLanguageCode.value = language.code!;
      
      // Save to storage
      SessionManager.instance.storage.write('selected_language', language.code);
      
      // Update app locale
      final locale = Locale(language.code!);
      await Get.updateLocale(locale);
      
      // Show success message
      SettingsErrorHandler.showSuccessSnackbar(
        'Language changed to \${language.localizedTitle ?? language.title}'.tr,
      );
      
      // Go back to settings after a brief delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        Get.back();
      });
      
    } catch (e) {
      print('Error selecting language: \$e');
      SettingsErrorHandler.handleError(e, customMessage: 'Failed to change language'.tr);
    }
  }

  // Get default languages if not available from server
  List<Language> _getDefaultLanguages() {
    return [
      Language(
        id: 1,
        code: 'en',
        title: 'English',
        localizedTitle: 'English',
        status: 1,
        isDefault: 1,
      ),
      Language(
        id: 2,
        code: 'es',
        title: 'Spanish',
        localizedTitle: 'Español',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 3,
        code: 'fr',
        title: 'French',
        localizedTitle: 'Français',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 4,
        code: 'de',
        title: 'German',
        localizedTitle: 'Deutsch',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 5,
        code: 'it',
        title: 'Italian',
        localizedTitle: 'Italiano',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 6,
        code: 'pt',
        title: 'Portuguese',
        localizedTitle: 'Português',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 7,
        code: 'ru',
        title: 'Russian',
        localizedTitle: 'Русский',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 8,
        code: 'ja',
        title: 'Japanese',
        localizedTitle: '日本語',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 9,
        code: 'ko',
        title: 'Korean',
        localizedTitle: '한국어',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 10,
        code: 'zh',
        title: 'Chinese',
        localizedTitle: '中文',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 11,
        code: 'ar',
        title: 'Arabic',
        localizedTitle: 'العربية',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 12,
        code: 'hi',
        title: 'Hindi',
        localizedTitle: 'हिन्दी',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 13,
        code: 'tr',
        title: 'Turkish',
        localizedTitle: 'Türkçe',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 14,
        code: 'nl',
        title: 'Dutch',
        localizedTitle: 'Nederlands',
        status: 1,
        isDefault: 0,
      ),
      Language(
        id: 15,
        code: 'sv',
        title: 'Swedish',
        localizedTitle: 'Svenska',
        status: 1,
        isDefault: 0,
      ),
    ];
  }

  // Get current language display name
  String getCurrentLanguageDisplayName() {
    final currentLang = languages.firstWhereOrNull(
      (lang) => lang.code == selectedLanguageCode.value,
    );
    return currentLang?.localizedTitle ?? currentLang?.title ?? 'English';
  }

  // Check if language is selected
  bool isLanguageSelected(String languageCode) {
    return selectedLanguageCode.value == languageCode;
  }

  // Reset language to default
  void resetToDefaultLanguage() {
    final defaultLang = languages.firstWhereOrNull(
      (lang) => lang.isDefault == 1,
    );
    
    if (defaultLang != null) {
      selectLanguage(defaultLang);
    } else {
      // Fallback to English
      final englishLang = languages.firstWhereOrNull(
        (lang) => lang.code == 'en',
      );
      if (englishLang != null) {
        selectLanguage(englishLang);
      }
    }
  }
}
