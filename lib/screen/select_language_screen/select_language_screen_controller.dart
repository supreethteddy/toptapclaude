import 'dart:io';

import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/eula_sheet.dart';
import 'package:shortzz/common/widget/restart_widget.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/select_language_screen/select_language_screen.dart';

class SelectLanguageScreenController
    extends BaseController {
  Rx<Language?> selectedLanguage = Rx(null);
  RxList<Language> languages = <Language>[].obs;
  LanguageNavigationType languageNavigationType;

  SelectLanguageScreenController(
      this.languageNavigationType);

  @override
  void onInit() {
    super.onInit();
    Loggers.info(
        '🔵 [LANG-CHECK] SelectLanguageScreenController onInit() called');
    Loggers.info(
        '🔵 [LANG-CHECK] Initial languages count: ${languages.length}');
    // Seed demo data when no settings are available (UI preview / offline)
    if (SessionManager.instance.getSettings() == null) {
      languages.assignAll([
        Language(
            title: 'English',
            code: 'en',
            status: 1,
            localizedTitle: 'English'),
        Language(
            title: 'Español',
            code: 'es',
            status: 1,
            localizedTitle: 'Spanish'),
        Language(
            title: 'Français',
            code: 'fr',
            status: 1,
            localizedTitle: 'French'),
      ]);
      selectedLanguage.value = languages.first;
    }
    initLanguage();
    Loggers.info(
        '🔵 [LANG-CHECK] After initLanguage, languages count: ${languages.length}');
  }

  @override
  void onReady() {
    super.onReady();
    if (languageNavigationType ==
        LanguageNavigationType.fromStart) {
      openEULASheet();
    }
  }

  Future<void> openEULASheet() async {
    if (Platform.isIOS) {
      bool shouldOpen =
          SessionManager.instance.shouldOpenEULASheet;

      await Future.delayed(
          const Duration(milliseconds: 250));
      Loggers.info('message  $shouldOpen');
      if (shouldOpen) {
        Get.bottomSheet(const EulaSheet(),
            isScrollControlled: true, enableDrag: false);
      }
    }
  }

  void initLanguage() {
    try {
      Loggers.info(
          '🌐 [LANG-CHECK] Starting language initialization...');

      // Check if settings exist
      final settings =
          SessionManager.instance.getSettings();
      if (settings == null) {
        Loggers.error(
            '❌ [LANG-CHECK] SessionManager.getSettings() returned NULL - API may have failed or no data seeded');
        languages.clear();
        selectedLanguage.value = null;
        return;
      }

      List<Language> items = settings.languages ?? [];
      Loggers.info(
          '📋 [LANG-CHECK] Raw languages from API: ${items.length} items');

      // Log all languages from API response
      if (items.isEmpty) {
        Loggers.error(
            '❌ [LANG-CHECK] No languages available in settings - Check API response: SessionManager.getSettings()?.languages');
        languages.clear();
        selectedLanguage.value = null;
        return;
      }

      // Log all languages with their status
      for (var lang in items) {
        Loggers.info(
            '   - ${lang.title} (${lang.code}): status=${lang.status}, csvFile=${lang.csvFile != null ? "✅" : "❌"}');
      }

      items.sort((a, b) =>
          (a.title ?? '').compareTo(b.title ?? ''));

      // Filter active languages (status == 1)
      int activeCount = 0;
      int inactiveCount = 0;
      for (Language element in items) {
        if (element.status == 1) {
          languages.add(element);
          activeCount++;
          Loggers.success(
              '✅ [LANG-CHECK] Active language: ${element.title} (${element.code})');
        } else {
          inactiveCount++;
          Loggers.warning(
              '⚠️ [LANG-CHECK] Inactive language (status=${element.status}): ${element.title} (${element.code})');
        }
      }

      // Validate languages list after filtering
      if (languages.isEmpty) {
        Loggers.error(
            '❌ [LANG-CHECK] No active languages found after filtering (status == 1)');
        Loggers.error(
            '   Total languages: ${items.length}, Active: $activeCount, Inactive: $inactiveCount');
        Loggers.error(
            '   ⚠️ Verify status == 1 for active languages in API response');
        selectedLanguage.value = null;
        return;
      }

      Loggers.success(
          '✅ [LANG-CHECK] Found $activeCount active languages out of ${items.length} total');

      // Get saved language code
      final savedLangCode =
          SessionManager.instance.getLang();
      Loggers.info(
          '💾 [LANG-CHECK] Saved language code: "$savedLangCode"');

      // Find matching language with safe fallback
      selectedLanguage.value = languages.firstWhere(
        (element) => element.code == savedLangCode,
        orElse: () {
          // Fallback to first language if saved language not found
          Loggers.warning(
              '⚠️ [LANG-CHECK] Language "$savedLangCode" not found in active languages, using first available: ${languages.first.code}');
          return languages.first;
        },
      );

      Loggers.success(
          '✅ [LANG-CHECK] Language initialized successfully: ${selectedLanguage.value?.code} (${selectedLanguage.value?.title})');
    } catch (e, stackTrace) {
      Loggers.error(
          '❌ [LANG-CHECK] Error initializing language: $e');
      Loggers.error('Stack trace: $stackTrace');
      // Set to null if any error occurs
      selectedLanguage.value = null;
    }
  }

  void onLanguageChange(Language? value) {
    if (value == null) {
      Loggers.error(
          '❌ [LANG-CHANGE] Cannot change to null language');
      return;
    }

    try {
      Loggers.info(
          '🔄 [LANG-CHANGE] Changing language to: ${value.code} (${value.title})');

      selectedLanguage.value = value;
      SessionManager.instance.setLang(value.code ?? 'en');

      // Verify Get.context is available
      if (Get.context == null) {
        Loggers.error(
            '❌ [LANG-CHANGE] Get.context is NULL - Cannot restart app!');
        Loggers.error(
            '   ⚠️ Verify Get.context! is not null during restart');
        return;
      }

      Loggers.info(
          '🔄 [LANG-CHANGE] Restarting app to apply language change...');
      RestartWidget.restartApp(Get.context!);
      Loggers.success(
          '✅ [LANG-CHANGE] Language changed successfully to: ${value.code}');
    } catch (e, stackTrace) {
      Loggers.error(
          '❌ [LANG-CHANGE] Error changing language: $e');
      Loggers.error('Stack trace: $stackTrace');
    }
  }
}
