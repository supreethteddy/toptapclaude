import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_native_video_trimmer/flutter_native_video_trimmer.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/sight_engine/sight_engine_media_model.dart';
import 'package:toptap/model/sight_engine/text_moderation_model.dart';
import 'package:toptap/utilities/app_res.dart';

class SightEngineService {
  static var shared = SightEngineService();

  Future<void> checkImagesInSightEngine({
    required List<XFile> xFiles,
    required Function() completion,
  }) async {
    if (SessionManager.instance.getSettings()?.isContentModeration == 0) {
      completion();
      return;
    }
    BaseController.share.showLoader();
    var request = http.MultipartRequest('POST',
        Uri.parse('https://api.sightengine.com/1.0/check-workflow.json'));

    request.fields['workflow'] =
        SessionManager.instance.getSettings()?.sightEngineImageWorkflowId ?? '';
    request.fields['api_user'] =
        SessionManager.instance.getSettings()?.sightEngineApiUser ?? '';
    request.fields['api_secret'] =
        SessionManager.instance.getSettings()?.sightEngineApiSecret ?? '';

    for (XFile xFile in xFiles) {
      File file = File(xFile.path);
      request.files.add(
        http.MultipartFile(
          'media',
          file.readAsBytes().asStream(),
          file.lengthSync(),
          filename: file.path.split("/").last,
        ),
      );
    }

    var response = await request.send();
    var respStr = await response.stream.bytesToString();
    SightEngineMediaModel sightEngineMediaModel =
        SightEngineMediaModel.fromJson(jsonDecode(respStr));

    if (sightEngineMediaModel.error != null) {
      BaseController.share.stopLoader();
      Loggers.error(sightEngineMediaModel.error?.message);
      BaseController.share
          .showSnackBar(sightEngineMediaModel.error?.message ?? '');
      return;
    }

    var result = sightEngineMediaModel.summary?.action ?? '';

    BaseController.share.stopLoader();
    if (result == 'accept') {
      completion(); // All images accepted
    } else if (result == 'reject') {
      var summaryDescription = sightEngineMediaModel.summary?.rejectReason
              ?.map((e) => e.text ?? '')
              .join(', ') ??
          '';
      BaseController.share.showSnackBar(
          '${LKey.mediaRejectedAndContainsSuchThings.tr} $summaryDescription');
    }
  }

  Future<void> checkVideoInSightEngine({required XFile xFile,
    required int duration,
    required Function() completion}) async {
    if (SessionManager.instance.getSettings()?.isContentModeration == 0) {
      completion();
      return;
    }

    final File sourceFile = File(xFile.path);
    if (!await sourceFile.exists()) {
      BaseController.share.showSnackBar(LKey.videoPathNotFound.tr);
      return;
    }

    BaseController.share.showLoader();
    final List<String> tempFiles = [];

    try {
      File sampleFile = sourceFile;
      if (duration > AppRes.sightEngineCropSec) {
        final trimmed = await _trimVideoForModeration(
          inputPath: sourceFile.path,
          startTimeMs: 0,
          endTimeMs: AppRes.sightEngineCropSec * 1000,
        );
        if (trimmed != null) {
          sampleFile = trimmed;
          tempFiles.add(trimmed.path);
        }
      }

      SightEngineMediaModel? moderation =
          await _submitVideoModeration(sampleFile);
      if (moderation == null) {
        BaseController.share.showSnackBar('Moderation failed. Please try again.');
        return;
      }

      if (moderation.error != null) {
        BaseController.share
            .showSnackBar(moderation.error?.message ?? '');
        return;
      }

      // Retry once with a middle clip for low-confidence rejects (common false-positives on first frames).
      if (_isLowConfidenceReject(moderation) &&
          duration > (AppRes.sightEngineCropSec + 1)) {
        final int middleStartSec =
            ((duration - AppRes.sightEngineCropSec) ~/ 2).clamp(0, duration);
        final int middleStartMs = middleStartSec * 1000;
        final int middleEndMs =
            middleStartMs + (AppRes.sightEngineCropSec * 1000);

        final middleClip = await _trimVideoForModeration(
          inputPath: sourceFile.path,
          startTimeMs: middleStartMs,
          endTimeMs: middleEndMs,
        );

        if (middleClip != null) {
          tempFiles.add(middleClip.path);
          final retryModeration =
              await _submitVideoModeration(middleClip);
          if (retryModeration != null &&
              retryModeration.error == null &&
              retryModeration.summary?.action == 'accept') {
            completion();
            return;
          }
          if (retryModeration != null) {
            moderation = retryModeration;
          }
        }
      }

      final result = moderation.summary?.action ?? '';
      if (result == 'accept') {
        completion();
        return;
      }

      if (result == 'reject') {
        final summaryDescription = moderation.summary?.rejectReason
                ?.map((e) => e.text ?? '')
                .where((e) => e.isNotEmpty)
                .join(', ') ??
            '';
        BaseController.share.showSnackBar(
            '${LKey.mediaRejectedAndContainsSuchThings.tr} $summaryDescription');
      } else {
        BaseController.share
            .showSnackBar('Moderation failed. Please try again.');
      }
    } catch (e) {
      Loggers.error(e);
      BaseController.share.showSnackBar('Moderation failed. Please try again.');
    } finally {
      BaseController.share.stopLoader();
      for (final path in tempFiles) {
        try {
          final tempFile = File(path);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<File?> _trimVideoForModeration({
    required String inputPath,
    required int startTimeMs,
    required int endTimeMs,
  }) async {
    final trimmer = VideoTrimmer();
    try {
      await trimmer.loadVideo(inputPath);
      final trimmedPath = await trimmer.trimVideo(
        startTimeMs: startTimeMs,
        endTimeMs: endTimeMs,
        includeAudio: false,
      );
      if (trimmedPath == null || trimmedPath.isEmpty) {
        return null;
      }

      final file = File(trimmedPath);
      if (!await file.exists() || await file.length() == 0) {
        return null;
      }
      return file;
    } catch (e) {
      Loggers.warning('Video trim failed for moderation: $e');
      return null;
    }
  }

  Future<SightEngineMediaModel?> _submitVideoModeration(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'https://api.sightengine.com/1.0/video/check-workflow-sync.json'),
    );
    request.fields['workflow'] =
        SessionManager.instance.getSettings()?.sightEngineVideoWorkflowId ?? '';
    request.fields['api_user'] =
        SessionManager.instance.getSettings()?.sightEngineApiUser ?? '';
    request.fields['api_secret'] =
        SessionManager.instance.getSettings()?.sightEngineApiSecret ?? '';

    request.files.add(
      http.MultipartFile(
        'media',
        file.readAsBytes().asStream(),
        file.lengthSync(),
        filename: file.path.split("/").last,
      ),
    );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    final dynamic decoded = jsonDecode(respStr);
    return SightEngineMediaModel.fromJson(decoded);
  }

  bool _isLowConfidenceReject(SightEngineMediaModel model) {
    if (model.summary?.action != 'reject') return false;
    final rejectProb = (model.summary?.rejectProb ?? 0).toDouble();
    if (rejectProb >= 0.9) return false;

    final reasons = model.summary?.rejectReason ?? [];
    if (reasons.isEmpty) return false;
    const ambiguousReasons = {
      'nudity.sextoy',
      'nudity.suggestive_pose',
      'nudity.suggestive_focus',
      'nudity.very_suggestive',
    };
    return reasons.every((r) => ambiguousReasons.contains(r.id));
  }

  Future<void> chooseTextModeration(
      {required String text, required Function() completion}) async {
    if (SessionManager.instance.getSettings()?.isContentModeration == 0) {
      completion();
      return;
    }
    if (text.isEmpty) {
      completion();
      return;
    }
    BaseController.share.showLoader();
    var request = http.MultipartRequest(
        'POST', Uri.parse('https://api.sightengine.com/1.0/text/check.json'));
    request.fields.addAll({
      'text': text,
      'lang': 'en,zh,da,nl,fi,fr,de,it,no,pl,pt,es,sv,tl,tr',
      'categories': 'profanity',
      'mode': 'rules',
      'api_user':
          SessionManager.instance.getSettings()?.sightEngineApiUser ?? '',
      'api_secret':
          SessionManager.instance.getSettings()?.sightEngineApiSecret ?? '',
    });

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      var respStr = await response.stream.bytesToString();
      TextModerationModel textModerationModel =
          TextModerationModel.fromJson(jsonDecode(respStr));
      List<Matches> matches = textModerationModel.profanity?.matches ?? [];
      print(jsonDecode(respStr));
      if (textModerationModel.error != null) {
        BaseController.share.stopLoader();
        BaseController.share
            .showSnackBar(textModerationModel.error?.message ?? '');
        return;
      }
      List<String> words = [];

      for (var element in matches) {
        if (element.intensity == 'high' || element.intensity == 'medium') {
          words.add(element.match ?? '');
        }
      }

      BaseController.share.stopLoader();
      if (words.isEmpty) {
        completion();
      } else {
        log('${LKey.textRejectedAndContainsSuchThings.tr} ${words.join(', ')}');
        BaseController.share.showSnackBar(
            '${LKey.textRejectedAndContainsSuchThings.tr} ${words.join(', ')}');
      }
    } else {
      log(response.reasonPhrase ?? '');
    }
  }
}
