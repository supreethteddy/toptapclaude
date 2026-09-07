import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/utils/profile_completion_helper.dart';
import 'package:shortzz/languages/dynamic_translations.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/screen/auth_screen/login_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen.dart';
import 'package:shortzz/screen/edit_profile_screen/edit_profile_screen.dart';
import 'package:shortzz/common/controller/live_status_controller.dart';
import 'package:shortzz/screen/gif_sheet/gif_sheet_controller.dart';
import 'package:shortzz/screen/select_language_screen/select_language_screen.dart';

class SplashScreenController extends BaseController {
  @override
  void onReady() {
    super.onReady();
    if (!Get.isRegistered<GifSheetController>()) {
      Get.put(GifSheetController());
    }
    if (!Get.isRegistered<FirebaseFirestoreController>()) {
      Get.put(FirebaseFirestoreController());
    }
    if (!Get.isRegistered<LiveStatusController>()) {
      Get.put(LiveStatusController(), permanent: true);
    }
    Future.wait([fetchSettings()]);
  }

  Future<void> fetchSettings() async {
    Loggers.info(
        '🌐 [TRANSLATION] Starting settings fetch...');

    bool showNavigate =
        await CommonService.instance.fetchGlobalSettings();

    if (showNavigate) {
      Loggers.success(
          '✅ [TRANSLATION] Settings fetched successfully');

      final translations = Get.find<DynamicTranslations>();

      // Check if languages exist in settings
      final settings =
          SessionManager.instance.getSettings();
      if (settings == null) {
        Loggers.error(
            '❌ [TRANSLATION] Settings object is NULL after fetch');
        return;
      }

      var languages = settings.languages ?? [];
      Loggers.info(
          '📋 [TRANSLATION] Total languages in API: ${languages.length}');

      if (languages.isEmpty) {
        Loggers.error(
            '❌ [TRANSLATION] No languages in API response');
        Loggers.error(
            '   ⚠️ Check API response: SessionManager.getSettings()?.languages');
      }

      List<Language> downloadLanguages = languages
          .where((element) => element.status == 1)
          .toList();

      Loggers.info(
          '📥 [TRANSLATION] Active languages to download: ${downloadLanguages.length}');

      if (downloadLanguages.isEmpty) {
        Loggers.warning(
            '⚠️ [TRANSLATION] No active languages to download (status != 1)');
      } else {
        // Log CSV file URLs
        for (var lang in downloadLanguages) {
          if (lang.csvFile == null ||
              lang.csvFile!.isEmpty) {
            Loggers.error(
                '❌ [TRANSLATION] Missing CSV file URL for: ${lang.code} (${lang.title})');
          } else {
            Loggers.info(
                '   ✅ ${lang.code}: ${lang.csvFile}');
          }
        }
      }

      var downloadedFiles = await downloadAndParseLanguages(
          downloadLanguages);

      Loggers.info(
          '📦 [TRANSLATION] Downloaded ${downloadedFiles.length} language files');

      if (downloadedFiles.isEmpty &&
          downloadLanguages.isNotEmpty) {
        Loggers.error(
            '❌ [TRANSLATION] Failed to download any translations!');
        Loggers.error(
            '   ⚠️ Check CSV file URLs in API response');
        Loggers.error(
            '   ⚠️ Verify internet connection during splash screen');
      }

      translations.addTranslations(downloadedFiles);
      Loggers.success(
          '✅ [TRANSLATION] Translations added to DynamicTranslations');

      var defaultLang = languages.firstWhereOrNull(
          (element) => element.isDefault == 1);

      if (defaultLang != null) {
        SessionManager.instance
            .setFallbackLang(defaultLang.code ?? 'en');
        Loggers.success(
            '✅ [TRANSLATION] Fallback language set to: ${defaultLang.code}');
      } else {
        Loggers.warning(
            '⚠️ [TRANSLATION] No default language found (isDefault == 1), using "en"');
        SessionManager.instance.setFallbackLang('en');
      }

      // Verify Get.context before restart
      if (Get.context == null) {
        Loggers.error(
            '❌ [TRANSLATION] Get.context is NULL - Cannot restart app!');
        Loggers.error(
            '   ⚠️ Ensure RestartWidget wraps MyApp in main.dart');
        return;
      }

      Loggers.info(
          '🔄 [TRANSLATION] Translations loaded, navigating...');

      // 🔒 Navigate BEFORE restart to ensure proper flow
      // RestartWidget will reinitialize GetX with new translations
      if (SessionManager.instance.isLogin()) {
        UserService.instance
            .fetchUserDetails(
                userId: SessionManager.instance.getUserID())
            .then((value) {
          if (value != null) {
            if (ProfileCompletionHelper.isProfileComplete(value)) {
              Get.off(() => DashboardScreen(myUser: value));
            } else {
              Get.off(() => EditProfileScreen(
                    isProfileCompletionRequired: true,
                    onUpdateUser: (updatedUser) {
                      if (ProfileCompletionHelper
                          .isProfileComplete(updatedUser)) {
                        Get.offAll(
                            () => DashboardScreen(myUser: updatedUser));
                      }
                    },
                  ));
            }
          } else {
            Get.off(() => const LoginScreen());
          }
        });
      } else {
        Get.off(() => const SelectLanguageScreen(
            languageNavigationType:
                LanguageNavigationType.fromStart));
      }

      // 🔒 DON'T call RestartWidget here - it breaks navigation!
      // RestartWidget.restartApp(Get.context!);
    } else {
      Loggers.error(
          '❌ [TRANSLATION] Settings fetch returned false');
    }
  }

  Future<Map<String, Map<String, String>>>
      downloadAndParseLanguages(
          List<Language> languages) async {
    Loggers.info(
        '📥 [DOWNLOAD] Starting parallel download of ${languages.length} languages...');

    const int maxConcurrentDownloads =
        3; // Limit concurrent downloads
    final Set<Future<void>> activeDownloads =
        {}; // Track active downloads
    final languageData = <String, Map<String, String>>{};

    int skippedCount = 0;
    for (var language in languages) {
      if (language.code == null) {
        Loggers.warning(
            '⚠️ [DOWNLOAD] Skipping language with null code: ${language.title}');
        skippedCount++;
        continue;
      }

      if (language.csvFile == null ||
          language.csvFile!.isEmpty) {
        Loggers.error(
            '❌ [DOWNLOAD] Missing CSV file for ${language.code} (${language.title})');
        skippedCount++;
        continue;
      }

      // Start the download and add it to the active set
      final downloadTask = downloadAndProcessLanguage(
          language, languageData);
      activeDownloads.add(downloadTask);

      // Limit concurrency
      if (activeDownloads.length >=
          maxConcurrentDownloads) {
        // Wait for any download to complete
        await Future.any(activeDownloads);

        // Remove completed tasks from the set
        activeDownloads.removeWhere(
            (task) => task == Future.any(activeDownloads));
      }
    }

    if (skippedCount > 0) {
      Loggers.warning(
          '⚠️ [DOWNLOAD] Skipped $skippedCount languages due to missing code or CSV file');
    }

    // Wait for all remaining downloads to complete
    if (activeDownloads.isNotEmpty) {
      Loggers.info(
          '⏳ [DOWNLOAD] Waiting for ${activeDownloads.length} remaining downloads...');
      await Future.wait(activeDownloads);
    }

    Loggers.success(
        '✅ [DOWNLOAD] Download complete. Successfully loaded: ${languageData.length}/${languages.length}');
    return languageData;
  }

  Future<void> downloadAndProcessLanguage(Language language,
      Map<String, Map<String, String>> languageData) async {
    final languageCode = language.code ?? 'unknown';
    final csvUrl = language.csvFile?.addBaseURL() ?? '';

    try {
      Loggers.info(
          '📥 [DOWNLOAD] Downloading ${language.title} ($languageCode)...');
      Loggers.info('   URL: $csvUrl');

      final response = await http
          .get(Uri.parse(csvUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        Loggers.success(
            '✅ [DOWNLOAD] HTTP 200 OK for $languageCode (${response.bodyBytes.length} bytes)');

        final csvContent = utf8.decode(response.bodyBytes);

        if (csvContent.isEmpty) {
          Loggers.error(
              '❌ [DOWNLOAD] Empty CSV content for $languageCode');
          return;
        }

        // Parse the CSV into a map
        final parsedMap = _parseCsvToMap(csvContent);

        if (parsedMap.isEmpty) {
          Loggers.warning(
              '⚠️ [DOWNLOAD] Parsed CSV is empty for $languageCode');
        } else {
          languageData[language.code!] = parsedMap;
          Loggers.success(
              '✅ [DOWNLOAD] Parsed $languageCode: ${parsedMap.length} translation keys');
        }
      } else {
        Loggers.error(
            '❌ [DOWNLOAD] Failed to download $languageCode: HTTP ${response.statusCode}');
        Loggers.error('   URL: $csvUrl');
        Loggers.error(
            '   ⚠️ Look for "Failed to download" errors in logs');
      }
    } on TimeoutException catch (e) {
      Loggers.error(
          '❌ [DOWNLOAD] Timeout downloading $languageCode (>30s): $e');
      Loggers.error(
          '   ⚠️ Verify internet connection during splash screen');
    } catch (e, stackTrace) {
      Loggers.error(
          '❌ [DOWNLOAD] Error downloading $languageCode: $e');
      Loggers.error('   URL: $csvUrl');
      Loggers.error('   Stack trace: $stackTrace');
      Loggers.error(
          '   ⚠️ Check CSV file URLs in API response');
    }
  }

  Map<String, String> _parseCsvToMap(String csvContent) {
    try {
      final rows =
          const CsvToListConverter().convert(csvContent);
      final map = <String, String>{};

      int validRows = 0;
      int skippedRows = 0;

      for (var row in rows) {
        if (row.length >= 2) {
          final key = row[0].toString().trim();
          final value = row[1].toString();

          if (key.isNotEmpty) {
            map[key] = value;
            validRows++;
          } else {
            skippedRows++;
          }
        } else {
          skippedRows++;
        }
      }

      if (validRows > 0) {
        Loggers.info(
            '📋 [CSV-PARSE] Parsed $validRows translation keys (skipped $skippedRows invalid rows)');
      } else {
        Loggers.warning(
            '⚠️ [CSV-PARSE] No valid rows found in CSV (total rows: ${rows.length})');
      }

      return map;
    } catch (e, stackTrace) {
      Loggers.error('❌ [CSV-PARSE] Error parsing CSV: $e');
      Loggers.error('Stack trace: $stackTrace');
      return {};
    }
  }
}
