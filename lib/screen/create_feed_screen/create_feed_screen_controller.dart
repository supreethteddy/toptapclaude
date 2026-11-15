import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:detectable_text_field/detectable_text_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:retrytech_plugin/retrytech_plugin.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/extensions/common_extension.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/functions/media_picker_helper.dart';
import 'package:toptap/common/manager/firebase_notification_manager.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/reactive_save_manager.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/api/add_post_story_service.dart';
import 'package:toptap/common/service/api/common_service.dart';
import 'package:toptap/common/service/api/post_service.dart';
import 'package:toptap/common/service/sight_engin/sight_engine_service.dart';
import 'package:toptap/common/service/utils/params.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/general/file_path_model.dart';
import 'package:toptap/model/general/location_place_model.dart';
import 'package:toptap/model/general/place_detail.dart';
import 'package:toptap/model/general/settings_model.dart';
import 'package:toptap/model/post_story/music/music_model.dart';
import 'package:toptap/model/post_story/post_model.dart';
import 'package:toptap/model/user_model/user_model.dart';
// Import shared camera types
import 'package:toptap/screen/camera_screen/camera_types.dart' as camera_types;
import 'package:toptap/screen/color_filter_screen/widget/color_filtered.dart';
import 'package:toptap/screen/comment_sheet/helper/comment_helper.dart';
import 'package:toptap/screen/create_feed_screen/create_feed_screen.dart';
import 'package:toptap/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:toptap/screen/profile_screen/profile_screen_controller.dart';
import 'package:toptap/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:video_player/video_player.dart';

enum DetectType { hashTag, atSign }

class CreateFeedScreenController extends BaseController {
  final dashboardController = Get.find<DashboardScreenController>();
  Rx<FeedPostType> feedPostType = FeedPostType.text.obs;
  RxBool canComment = true.obs;
  final RetrytechPlugin _retrytechPlugin = RetrytechPlugin();

  CommentHelper commentHelper = CommentHelper();
  User? myUser = SessionManager.instance.getUser();
  RxList<ImageWithFilter> images = <ImageWithFilter>[].obs;
  List<num> mentionUserIds = [];

  Rx<ImageWithFilter?> video = Rx(null);
  Rx<Places?> selectedLocation = Rx(null);
  RxDouble progress = 0.0.obs;
  RxBool isUploadingPost = false.obs;
  Rx<VideoPlayerController?> videoPlayerController = Rx(null);
  RxInt selectedImageIndex = 0.obs;
  Function({Post? post, CreateFeedType? type})? onAddPost;
  CreateFeedType createType;
  Rx<camera_types.PostStoryContent?> content;

  Rx<Setting?> setting = Rx(null);

  // CRITICAL FIX: Add video editing controller to preserve edits
  dynamic videoEditingController;

  CreateFeedScreenController(this.onAddPost, this.createType, this.content,
      [this.videoEditingController]);

  UploadType _lastUploadType = UploadType.none;
  String? _lastUploadErrorMessage;

  String localPath = '';

  @override
  Future<void> onInit() async {
    localPath = await PlatformPathExtension.localPath;
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    Future.wait({_fetchSetting()});
    _initializeContentFromCamera();
  }

  void _initializeContentFromCamera() {
    print('🔍 DEBUG: _initializeContentFromCamera called');
    // Check if content was passed from camera
    final contentValue = content.value;
    print('🔍 DEBUG: content.value = $contentValue');
    if (contentValue != null && contentValue.content != null) {
      print('🔍 DEBUG: contentValue.content = ${contentValue.content}');
      print('🔍 DEBUG: contentValue.type = ${contentValue.type}');
      switch (contentValue.type) {
        case camera_types.PostStoryContentType.storyImage:
          // Initialize image from camera content
          final imageFile = XFile(contentValue.content!);
          images.add(ImageWithFilter(media: imageFile, thumbnail: imageFile));
          feedPostType.value = FeedPostType.image;
          print(
              '✅ Image initialized from camera content: ${contentValue.content}');
          break;
        case camera_types.PostStoryContentType.storyVideo:
          // Initialize video from camera content
          final videoFile = XFile(contentValue.content!);
          video.value = ImageWithFilter(media: videoFile, thumbnail: videoFile);
          feedPostType.value = FeedPostType.video;

          // Initialize video player controller for camera video
          videoPlayerController.value =
              VideoPlayerController.file(File(contentValue.content!))
                ..initialize().then((value) {
                  print(
                      '🔍 DEBUG: Video player initialized for: ${contentValue.content}');
                  videoPlayerController.refresh();
                });

          print(
              '✅ Video initialized from camera content: ${contentValue.content}');
          print(
              '🔍 DEBUG: Checking if file exists: ${File(contentValue.content!).existsSync()}');
          break;
        default:
          print('⚠️ Content type not supported for feed: ${contentValue.type}');
      }
    } else {
      print('🔍 DEBUG: No content received from camera or content is null');
    }
  }

  @override
  void onClose() {
    super.onClose();
    videoPlayerController.value?.dispose();
  }

  Future _fetchSetting() async {
    setting.value = SessionManager.instance.getSettings();
    bool result = await CommonService.instance.fetchGlobalSettings();
    if (result == true) {
      setting.value = SessionManager.instance.getSettings();
    }
  }

  void handleUpload() async {
    if (isUploadingPost.value) {
      _showStatusMessage(
        title: 'Upload in progress',
        message: 'Please wait until the current upload finishes.',
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        icon: const Icon(Icons.hourglass_top_rounded, color: Colors.white),
        duration: const Duration(seconds: 2),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    // Early return if nothing to upload for feed posts
    if (_shouldAbortUpload()) {
      Loggers.warning('Nothing to upload. Aborting...');
      return;
    }
    final rawDescription = commentHelper.detectableTextController.text;

    final postParams = await _buildPostParams(rawDescription);

    Loggers.info('Post Data: $postParams');

    if (createType == CreateFeedType.reel) {
      _uploadPostHandler(postParams);
    } else {
      runContentModerationAndUpload(
        description: rawDescription,
        params: postParams,
      );
    }
  }

  bool _shouldAbortUpload() {
    return createType == CreateFeedType.feed &&
        images.isEmpty &&
        video.value == null &&
        commentHelper.detectableTextController.text.isEmpty;
  }

  Future<Map<String, dynamic>> _buildPostParams(String rawDescription) async {
    final params = <String, dynamic>{
      if (rawDescription.isNotEmpty) Params.description: rawDescription,
      Params.canComment: canComment.value ? 1 : 0,
    };

    _addTextDetections(params, rawDescription);
    _addLocationData(params);

    if (selectedLocation.value == null && createType == CreateFeedType.reel) {
      await _addCurrentLocationData(params);
    }

    return params;
  }

  void _addTextDetections(Map<String, dynamic> params, String rawDescription) {
    final mentionUsernames = _extractUniqueMentions(rawDescription);
    final hashtags = _extractUniqueHashtags(rawDescription);
    final processedDescription =
        _processMentions(rawDescription, mentionUsernames);

    if (processedDescription != rawDescription) {
      params[Params.description] = processedDescription;
    }

    if (hashtags.isNotEmpty) {
      params[Params.hashtags] = hashtags.join(',');
    }

    if (mentionUserIds.isNotEmpty) {
      params[Params.mentionedUserIds] = mentionUserIds.join(',');
    }
  }

  List<String> _extractUniqueMentions(String text) {
    return TextPatternDetector.extractDetections(text, atSignRegExp)
        .where((text) => text.contains('@'))
        .map((text) => text.replaceAll('@', ''))
        .toSet()
        .toList();
  }

  List<String> _extractUniqueHashtags(String text) {
    return TextPatternDetector.extractDetections(text, hashTagRegExp)
        .where((text) => text.contains('#'))
        .map((text) => text.replaceAll('#', ''))
        .toSet()
        .toList();
  }

  String _processMentions(String text, List<String> mentionUsernames) {
    var processedText = text;

    for (final username in mentionUsernames) {
      final user = commentHelper.allMentionUsers
          .firstWhereOrNull((u) => u.username == username);
      if (user != null && user.id != null) {
        processedText = processedText.replaceAllMapped(
          RegExp(RegExp.escape('@$username')),
          (_) => '@${user.id}',
        );
        mentionUserIds.addIf(!mentionUserIds.contains(user.id), user.id!);
      }
    }

    return processedText;
  }

  void _addLocationData(Map<String, dynamic> params) {
    final location = selectedLocation.value;
    if (location == null) return;

    params.addAll({
      Params.country: location.shortCountry,
      Params.state: location.shortState,
      Params.placeTitle: location.placeTitle,
      Params.placeLat: '${location.location?.latitude ?? ''}',
      Params.placeLon: '${location.location?.longitude ?? ''}',
    });
  }

  Future<void> _addCurrentLocationData(Map<String, dynamic> params) async {
    Position? position;
    PlaceDetail? detail;
    try {
      position = await Geolocator.getCurrentPosition();
      detail = await CommonService.instance.getIPPlaceDetail();
    } catch (e) {
      Loggers.error('_addCurrentLocationData $e');
    }
    if (detail != null && detail.status == 'success') {
      params.addAll({
        Params.country: detail.country,
        Params.state: detail.region,
        Params.placeLat: '${position?.latitude ?? detail.lat}',
        Params.placeLon: '${position?.longitude ?? detail.lon}',
      });
    }
  }

  void runContentModerationAndUpload(
      {required String description, required Map<String, dynamic> params}) {
    switch (feedPostType.value) {
      case FeedPostType.image:
        Loggers.info('Running SightEngine image moderation...');
        List<XFile> imageFiles = images.map((img) => img.media).toList();
        SightEngineService.shared.checkImagesInSightEngine(
          xFiles: imageFiles,
          completion: () {
            _uploadPostHandler(params);
          },
        );
        break;
      case FeedPostType.text:
        Loggers.info('Running SightEngine text moderation...');
        SightEngineService.shared.chooseTextModeration(
          text: description,
          completion: () {
            _uploadPostHandler(params);
          },
        );
        break;
      case FeedPostType.video:
        Loggers.info('Running SightEngine video moderation...');
        SightEngineService.shared.checkVideoInSightEngine(
          xFile: video.value!.media,
          duration: videoPlayerController.value?.value.duration.inSeconds ?? 0,
          completion: () {
            _uploadPostHandler(params);
          },
        );
        break;
    }
  }

  Future<void> _uploadPostHandler(Map<String, dynamic> postParams) async {
    // 🔧 FIX: Don't close screens yet - wait until upload completes
    Loggers.info('Post upload initiated...');

    PostModel? postResponse;
    _lastUploadErrorMessage = null;
    isUploadingPost.value = true;
    _lastUploadType = UploadType.uploading;
    updateUploadingProgress(progress: 0);

    await Future.delayed(const Duration(seconds: 1));

    try {
      // Handle post upload based on post type
      switch (createType) {
        case CreateFeedType.reel:
          Loggers.info('Uploading Reel...');
          postResponse = await _handleReelUpload(content.value, postParams);
          break;

        case CreateFeedType.feed:
          switch (feedPostType.value) {
            case FeedPostType.image:
              Loggers.info('Uploading Image post...');
              postResponse = await _handleImageUpload(postParams);
              break;
            case FeedPostType.text:
              Loggers.info('Uploading Text post...');

              updateUploadingProgress(progress: 90);
              if (commentHelper.metaData.value != null) {
                postParams[Params.metadata] =
                    jsonEncode(commentHelper.metaData.value);
              }
              postResponse = await AddPostStoryService.instance
                  .addPostFeedText(param: postParams);
              break;
            case FeedPostType.video:
              Loggers.info('Uploading Video post...');
              postResponse = await _handleVideoUpload(postParams);
              break;
          }
      }

      // Check result and update progress
      if (postResponse == null) {
        final failureReason = _lastUploadErrorMessage?.trim();
        Loggers.error(
            'Post upload failed ❌: ${failureReason?.isNotEmpty == true ? failureReason : 'empty response'}');
        return;
      }

      if (postResponse.status == true) {
        Post? post = postResponse.data;
        if (post == null) {
          failedResponseSnackBar(message: 'Post not found');
          return;
        }
        Loggers.success('Post uploaded successfully ✅');
        _lastUploadErrorMessage = null;

        _lastUploadType = UploadType.finish;
        updateUploadingProgress(progress: 100);

        // 🎉 Show success message to user
        _showSuccessMessage(post, createType);

        // Notify profile controller if available
        if (Get.isRegistered<ProfileScreenController>(
            tag: ProfileScreenController.tag)) {
          final profileController = Get.find<ProfileScreenController>(
              tag: ProfileScreenController.tag);
          profileController.onAddPost(post: post, type: createType);
        }

        // 🔄 Integration with ReactiveSaveManager for automatic save state
        if (Get.isRegistered<ReactiveSaveManager>()) {
          final saveManager = Get.find<ReactiveSaveManager>();
          // Add the new post to tracking
          saveManager.trackNewPost(post);
        }

        Loggers.info('''
                Post ID: ${post.id}
                Mention User IDs: ${post.mentionedUsers?.map((e) => e.id).toList()} 
              ''');

        // 🔧 FIX: Let users see success feedback before navigating away
        await Future.delayed(const Duration(milliseconds: 1800));

        // Don't close screens here - let _navigateToCorrectDestination handle it
        try {
          await _navigateToCorrectDestination(post, createType);
        } catch (e) {
          Loggers.warning('Navigation error (ignored): $e');
        }
        try {
          _notifyMentionedUsers(post);
        } catch (e) {
          Loggers.warning('Notify mentioned users failed: $e');
        }
      } else {
        final errorMessage = postResponse.message?.trim();
        Loggers.error(
            'Post upload failed ❌: ${errorMessage?.isNotEmpty == true ? errorMessage : 'Unknown server error'}');

        // Check if this is a device-specific provider error (OnePlus analytics)
        String? providerErrorMessage = postResponse.message;
        if (providerErrorMessage != null &&
            (providerErrorMessage.contains('oplus.statistics.provider') ||
                providerErrorMessage.contains('OplusStatistics') ||
                providerErrorMessage.contains('provider info'))) {
          Loggers.warning(
              '⚠️ OnePlus provider error detected - checking if upload actually succeeded');

          // Show a more user-friendly message for provider errors
          _showStatusMessage(
            title: 'Upload Warning',
            message:
                'Upload may have completed but analytics failed. Please check your profile.',
            backgroundColor: Colors.orange.withValues(alpha: 0.9),
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
            duration: const Duration(seconds: 4),
          );

          return; // Don't show the generic failure message
        }

        failedResponseSnackBar(
            message: errorMessage?.isNotEmpty == true
                ? errorMessage
                : 'Upload failed. Please try again.');
      }
    } catch (e, stacktrace) {
      Loggers.error('Exception during post upload: $e');
      Loggers.error(stacktrace.toString());

      // Handle device-specific provider errors
      String errorMessage = e.toString();
      if (errorMessage.contains('oplus.statistics.provider') ||
          errorMessage.contains('OplusStatistics') ||
          errorMessage.contains('provider info')) {
        Loggers.warning(
            '⚠️ OnePlus provider exception detected - this is usually safe to ignore');

        _showStatusMessage(
          title: 'Upload Status',
          message:
              'Upload may have completed despite analytics error. Please check your profile.',
          backgroundColor: Colors.orange.withValues(alpha: 0.9),
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          duration: const Duration(seconds: 5),
        );

        _lastUploadType = UploadType.finish;
        updateUploadingProgress(progress: 100);
        return;
      }

      failedResponseSnackBar(message: '$e');
    } finally {
      isUploadingPost.value = false;
    }
  }

  Future<void> _notifyMentionedUsers(Post post) async {
    const int batchSize = 5;
    List<Future> batch = [];

    for (final mentionUser in (post.mentionedUsers ?? [])) {
      if (mentionUser.notifyMention == 1 && mentionUser.id != myUser?.id) {
        batch.add(
            FirebaseNotificationManager.instance.sendLocalisationNotification(
          LKey.notifyMentionedInPost.tr,
          type: NotificationType.post,
          body: NotificationInfo(id: post.id),
          deviceType: mentionUser.device,
          deviceToken: mentionUser.deviceToken ?? '',
          languageCode: mentionUser.appLanguage,
        ));

        if (batch.length >= batchSize) {
          await Future.wait(batch);
          batch.clear();
        }
      }
    }

    if (batch.isNotEmpty) {
      await Future.wait(batch);
    }
  }

  Future<PostModel?> _handleReelUpload(camera_types.PostStoryContent? content,
      Map<String, dynamic> params) async {
    if (content == null) {
      return failedResponseSnackBar(message: 'Invalid content');
    }

    final String videoPath = content.content ?? '';
    final String extractAudioPath = '${localPath}extract_audio.m4a';

    // CRITICAL FIX: Enhanced video path validation
    if (videoPath.isEmpty) {
      Loggers.error('Video path is empty for reel upload');
      return failedResponseSnackBar(
          message: 'Video not found - recording may have failed');
    }

    // CRITICAL FIX: Verify video file exists and has valid size
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) {
      Loggers.error('Video file does not exist: $videoPath');
      return failedResponseSnackBar(
          message: 'Video file not found - please try recording again');
    }

    final fileSize = await videoFile.length();
    if (fileSize < 100000) {
      // Less than 100KB is likely corrupted
      Loggers.error('Video file too small: $fileSize bytes at $videoPath');
      return failedResponseSnackBar(
          message: 'Video file corrupted - please record a new video');
    }

    Loggers.success('Video validation passed: $fileSize bytes at $videoPath');

    SelectedMusic? selectedMusic = content.sound;
    bool hasAudio = content.hasAudio;
    Music? uploadedMusic;
    final List<String?> tempFiles = [];

    if (hasAudio) {
      if (selectedMusic == null) {
        final duration = Duration(seconds: content.duration ?? 0);

        final String artistName = myUser?.username ?? 'Unknown';

        Loggers.info('Extracting audio from video...');
        bool? success = await _retrytechPlugin.extractAudio(
            inputPath: videoPath, outputPath: extractAudioPath);

        if (success == false) {
          deleteFiles([extractAudioPath]);
          return failedResponseSnackBar(message: 'Audio extraction failed.');
        }
        tempFiles.add(extractAudioPath);

        Loggers.success('Audio extracted at: $extractAudioPath');

        // Load profile image or fallback to thumbnail
        final XFile? profileImage =
            await _loadProfileOrThumbnailImage(content.thumbNail);

        Loggers.info('Uploading extracted music...');
        uploadedMusic = await PostService.instance.addUserMusic(
          title: AppRes.addMusicName,
          duration: '${duration.inMinutes}:${duration.inSeconds % 60}',
          artist: artistName,
          sound: XFile(extractAudioPath),
          image: profileImage,
        );

        Loggers.success('Music uploaded: ${uploadedMusic?.title}');
      } else {
        uploadedMusic = selectedMusic.music;
      }

      params[Params.soundID] = uploadedMusic?.id;

      if (uploadedMusic == null) {
        deleteFiles(tempFiles);
        return failedResponseSnackBar(message: 'Music not found');
      }
    }

    // progress.value = 10;
    updateUploadingProgress(progress: 10);

    // Step 5: Upload video & thumbnail
    XFile finalVideoFile = XFile(videoPath);
    XFile finalThumbnailFile = XFile(content.thumbNail ?? '');
    if (finalThumbnailFile.path.isEmpty ||
        !File(finalThumbnailFile.path).existsSync()) {
      finalThumbnailFile = await MediaPickerHelper.shared
          .extractThumbnail(videoPath: finalVideoFile.path);
      if (finalThumbnailFile.path.isNotEmpty) {
        tempFiles.add(finalThumbnailFile.path);
      }
    }
    if (finalThumbnailFile.path.isEmpty ||
        !File(finalThumbnailFile.path).existsSync()) {
      deleteFiles(tempFiles);
      return failedResponseSnackBar(
          message: 'Thumbnail generation failed. Please try another video.');
    }

    XFile uploadReadyVideo = await _createSafeUploadCopy(
      source: finalVideoFile,
      prefix: 'reel_video',
      tempFiles: tempFiles,
    );

    XFile uploadReadyThumbnail = await _createSafeUploadCopy(
      source: finalThumbnailFile,
      prefix: 'reel_thumb',
      tempFiles: tempFiles,
    );

    Loggers.info('Uploading video...');
    FilePathModel uploadedVideo;
    try {
      uploadedVideo =
          await CommonService.instance.uploadFileGivePath(uploadReadyVideo);
    } catch (e) {
      Loggers.warning('Reel video upload failed: $e');
      if (!_shouldRetryCompressedUpload(e)) {
        deleteFiles(tempFiles);
        return failedResponseSnackBar(
            message: _resolveUploadFailureMessage(
          e,
          fallback: 'Video upload failed. Please try again.',
        ));
      }

      XFile? retryCompressedVideo = await MediaPickerHelper.shared
          .compressVideoLowQuality(finalVideoFile.path);
      if (retryCompressedVideo == null ||
          retryCompressedVideo.path.isEmpty ||
          !File(retryCompressedVideo.path).existsSync()) {
        deleteFiles(tempFiles);
        return failedResponseSnackBar(
            message:
                'Video upload failed. Unable to prepare compressed retry file.');
      }

      tempFiles.add(retryCompressedVideo.path);
      finalVideoFile = retryCompressedVideo;
      uploadReadyVideo = await _createSafeUploadCopy(
        source: finalVideoFile,
        prefix: 'reel_video_retry',
        tempFiles: tempFiles,
      );
      try {
        uploadedVideo =
            await CommonService.instance.uploadFileGivePath(uploadReadyVideo);
      } catch (retryError) {
        deleteFiles(tempFiles);
        return failedResponseSnackBar(
            message:
                'Video upload failed after retry. Please try a shorter video.');
      }
    }

    if (uploadedVideo.status != true ||
        uploadedVideo.data == null ||
        uploadedVideo.data!.isEmpty) {
      Loggers.warning(
          'Reel video upload invalid response: status=${uploadedVideo.status}, message=${uploadedVideo.message}, data=${uploadedVideo.data}');

      XFile? retryCompressedVideo = await MediaPickerHelper.shared
          .compressVideoLowQuality(finalVideoFile.path);
      if (retryCompressedVideo != null &&
          retryCompressedVideo.path.isNotEmpty &&
          File(retryCompressedVideo.path).existsSync()) {
        tempFiles.add(retryCompressedVideo.path);
        finalVideoFile = retryCompressedVideo;
        uploadReadyVideo = await _createSafeUploadCopy(
          source: finalVideoFile,
          prefix: 'reel_video_retry_status',
          tempFiles: tempFiles,
        );
        try {
          uploadedVideo =
              await CommonService.instance.uploadFileGivePath(uploadReadyVideo);
        } catch (_) {}
      }

      if (uploadedVideo.status != true ||
          uploadedVideo.data == null ||
          uploadedVideo.data!.isEmpty) {
        deleteFiles(tempFiles);
        return failedResponseSnackBar(
            message: uploadedVideo.message?.isNotEmpty == true
                ? uploadedVideo.message
                : 'Video upload failed. Please try a shorter video.');
      }
    }

    Loggers.info('Uploading thumbnail...');
    FilePathModel uploadedThumb;
    try {
      uploadedThumb =
          await CommonService.instance.uploadFileGivePath(uploadReadyThumbnail);
    } catch (e) {
      deleteFiles(tempFiles);
      return failedResponseSnackBar(
          message: 'Thumbnail upload failed. Please try again.');
    }

    // Step 6: Check upload success
    if (uploadedThumb.status != true ||
        uploadedThumb.data == null ||
        uploadedThumb.data!.isEmpty) {
      Loggers.warning(
          'Reel thumbnail upload invalid response: status=${uploadedThumb.status}, message=${uploadedThumb.message}, data=${uploadedThumb.data}');

      // Retry thumbnail once by regenerating and compressing from final video.
      try {
        final regeneratedThumb = await MediaPickerHelper.shared
            .extractThumbnail(videoPath: finalVideoFile.path);
        if (regeneratedThumb.path.isNotEmpty &&
            File(regeneratedThumb.path).existsSync()) {
          tempFiles.add(regeneratedThumb.path);
          XFile uploadThumb = regeneratedThumb;
          final compressedThumb = await MediaPickerHelper.shared.compressImage(
              regeneratedThumb.path, '${localPath}reel_thumb_retry.jpg');
          if (compressedThumb != null &&
              compressedThumb.path.isNotEmpty &&
              File(compressedThumb.path).existsSync()) {
            uploadThumb = compressedThumb;
            tempFiles.add(compressedThumb.path);
          }

          final uploadReadyRetryThumb = await _createSafeUploadCopy(
            source: uploadThumb,
            prefix: 'reel_thumb_retry',
            tempFiles: tempFiles,
          );
          uploadedThumb = await CommonService.instance
              .uploadFileGivePath(uploadReadyRetryThumb);
        }
      } catch (e) {
        Loggers.warning('Reel thumbnail retry failed: $e');
      }
    }

    if (uploadedVideo.status != true ||
        uploadedVideo.data == null ||
        uploadedVideo.data!.isEmpty ||
        uploadedThumb.status != true ||
        uploadedThumb.data == null ||
        uploadedThumb.data!.isEmpty) {
      deleteFiles(tempFiles);
      return failedResponseSnackBar(
          message: uploadedVideo.message?.isNotEmpty == true
              ? uploadedVideo.message
              : (uploadedThumb.message?.isNotEmpty == true
                  ? uploadedThumb.message
                  : 'Video or thumbnail upload failed.'));
    }

    deleteFiles(tempFiles);

    // progress.value = 90;
    updateUploadingProgress(progress: 90);

    // Prepare final post params
    params[Params.video] = uploadedVideo.data;
    params[Params.thumbnail] = uploadedThumb.data;

    // Final post upload
    try {
      Loggers.info('Uploading final post...');
      PostModel result =
          await AddPostStoryService.instance.addPostReel(param: params);
      return result;
    } catch (e) {
      return failedResponseSnackBar(message: '$e');
    }
  }

  Future<XFile?> _loadProfileOrThumbnailImage(String? fallbackThumb) async {
    try {
      String profileImage = myUser?.profilePhoto ?? '';

      if (profileImage.isEmpty) {
        return null;
      }

      final file =
          await DefaultCacheManager().getSingleFile(profileImage.addBaseURL());
      Loggers.success('Loaded profile image from URL.');
      return XFile(file.path);
    } catch (e) {
      Loggers.error('Error loading profile image: $e');
    }

    Loggers.info('Using fallback thumbnail.');
    return XFile(fallbackThumb ?? '');
  }

  Future<PostModel?> _handleImageUpload(Map<String, dynamic> params) async {
    if (images.isEmpty) {
      Loggers.warning('No images selected for upload.');
      return failedResponseSnackBar(message: 'No images to upload');
    }

    Loggers.info('Starting image upload...');

    // Step 1: Apply filters if any
    List<XFile> filterImages = await Future.wait(
      images.map((image) async {
        bool isFilterApply = !listEquals(image.colorFilter, defaultFilter);
        if (isFilterApply) {
          Loggers.info('Applying color filter to image at ${image.media.path}');
          String outputPath =
              '$localPath${images.indexOf(image)}filter_image.jpg';
          bool? result = await _retrytechPlugin.applyFilterToImage(
              inputPath: image.media.path,
              filterValues: image.colorFilter,
              outputPath: outputPath);
          if (result == true) {
            Loggers.success('Filter applied: $outputPath');
            return XFile(outputPath);
          } else {
            Loggers.warning('Filter failed, using original image.');
          }
        }
        return XFile(image.media.path);
      }),
    );

    Loggers.info('Apply Filters : ${filterImages.map((e) => e.path)}');

    updateUploadingProgress(progress: 10);

    List<String> compressImages = [];

    // Step 2: Compress each image
    if (setting.value?.isCompress == 1) {
      for (int i = 0; i < filterImages.length; i++) {
        XFile? imageFile = filterImages[i];

        Loggers.info('Compressing image: ${imageFile.path}');
        XFile? _compressImageFile = await MediaPickerHelper.shared
            .compressImage(
                imageFile.path, '${localPath}compress_images_$i.jpg');
        if (_compressImageFile != null) {
          compressImages.add(_compressImageFile.path);
        } else {
          compressImages.add(imageFile.path);
        }
        Loggers.info('Uploading image: ${imageFile.path}');
      }
    } else {
      for (int i = 0; i < filterImages.length; i++) {
        compressImages.add(filterImages[i].path);
      }
    }

    updateUploadingProgress(progress: 30);

    Loggers.info('Compress image : ${compressImages.map((e) => e)}');

    // Step 3: Uploading each image
    List<String> uploadedImagePaths = [];
    for (var image in compressImages) {
      final result =
          await CommonService.instance.uploadFileGivePath(XFile(image));
      if (result.status == true && result.data != null) {
        uploadedImagePaths.add(result.data!);
        Loggers.success('Image uploaded: ${result.data}');
      } else {
        Loggers.error('Image upload failed: ${result.message}');
        deleteFiles(images.map((e) => e.media.path).toList() +
            filterImages.map((e) => e.path).toList() +
            compressImages);
        return failedResponseSnackBar(message: result.message);
      }
    }
    updateUploadingProgress(progress: 90);

    // Step 4: Add uploaded image paths to params
    for (int i = 0; i < uploadedImagePaths.length; i++) {
      params['${Params.postImages}[$i]'] = uploadedImagePaths[i];
    }

    // Delete temporary files
    deleteFiles(images.map((e) => e.media.path).toList() +
        filterImages.map((e) => e.path).toList() +
        compressImages);

    Loggers.info('Uploading final post... $params');

    // Step 5: Upload final post
    try {
      final postResult =
          await AddPostStoryService.instance.addPostFeedImage(param: params);
      return postResult;
    } catch (e) {
      Loggers.error('Exception during post upload: $e');
      return failedResponseSnackBar(message: '$e');
    }
  }

  Future<PostModel?> _handleVideoUpload(Map<String, dynamic> params) async {
    ImageWithFilter? videoData = video.value;
    if (videoData == null) {
      return failedResponseSnackBar(message: 'Video not found');
    }
    Loggers.info('Starting video upload...');

    final List<String?> tempFiles = [];
    String inputVideoPath = videoData.media.path;
    XFile finalThumbnailFile = videoData.thumbnail;
    bool isApplyFilter = !listEquals(videoData.colorFilter, defaultFilter);

    XFile finalVideoFile = XFile(inputVideoPath);
    String outputVideoPath = '${localPath}filter_video.mp4';

    if (inputVideoPath.isEmpty) {
      Loggers.error('Input video path is empty');
      return null;
    }

    // Step 1: Apply color filter if present
    if (isApplyFilter) {
      bool? result = await _retrytechPlugin.applyFilterAndAudioToVideo(
          inputPath: inputVideoPath,
          outputPath: outputVideoPath,
          filterValues: videoData.colorFilter,
          shouldBothMusics: true);
      if (result == true) {
        Loggers.info('Applying color filter to video...');
        finalVideoFile = XFile(outputVideoPath);
        tempFiles.add(outputVideoPath);
        // Step 2: Extract thumbnail from the final video
        Loggers.info('Extracting thumbnail...');
        finalThumbnailFile = await MediaPickerHelper.shared
            .extractThumbnail(videoPath: finalVideoFile.path);
        if (finalThumbnailFile.path.isNotEmpty) {
          tempFiles.add(finalThumbnailFile.path);
        }
      } else {
        return failedResponseSnackBar(message: 'Color filter failed');
      }
    } else {
      Loggers.info('No color Add, using original video.');
    }

    updateUploadingProgress(progress: 10);

    // Step 3: Optional compression
    if (setting.value?.isCompress == 1) {
      Loggers.info('Compressing video and thumbnail...');
      XFile? compressVideoFile =
          await MediaPickerHelper.shared.compressVideo(finalVideoFile.path, '');
      if (compressVideoFile != null) {
        if (compressVideoFile.path != finalVideoFile.path) {
          tempFiles.add(compressVideoFile.path);
        }
        finalVideoFile = compressVideoFile;
      } else {
        Loggers.error('Compression failed: null video');
      }

      if (finalThumbnailFile.path.isEmpty ||
          !File(finalThumbnailFile.path).existsSync()) {
        finalThumbnailFile = await MediaPickerHelper.shared
            .extractThumbnail(videoPath: finalVideoFile.path);
        if (finalThumbnailFile.path.isNotEmpty) {
          tempFiles.add(finalThumbnailFile.path);
        }
      }

      XFile? compressThumbFile = await MediaPickerHelper.shared.compressImage(
          finalThumbnailFile.path, '${localPath}compress_video_thumb.jpg');
      if (compressThumbFile != null) {
        if (compressThumbFile.path != finalThumbnailFile.path) {
          tempFiles.add(compressThumbFile.path);
        }
        finalThumbnailFile = compressThumbFile;
      } else {
        Loggers.error('Compression failed: null Thumbnail');
      }
    }

    // Ensure thumbnail is always available and valid
    if (finalThumbnailFile.path.isEmpty ||
        !File(finalThumbnailFile.path).existsSync()) {
      Loggers.warning('Thumbnail missing, regenerating from video...');
      finalThumbnailFile = await MediaPickerHelper.shared
          .extractThumbnail(videoPath: finalVideoFile.path);
      if (finalThumbnailFile.path.isNotEmpty) {
        tempFiles.add(finalThumbnailFile.path);
      }
    }

    if (finalThumbnailFile.path.isEmpty ||
        !File(finalThumbnailFile.path).existsSync()) {
      return failedResponseSnackBar(
          message: 'Thumbnail generation failed. Please try another video.');
    }

    updateUploadingProgress(progress: 30);

    // Prepare upload-safe copies (avoids server issues with special filenames)
    XFile uploadReadyVideo;
    XFile uploadReadyThumbnail;
    try {
      uploadReadyVideo = await _createSafeUploadCopy(
        source: finalVideoFile,
        prefix: 'feed_video',
        tempFiles: tempFiles,
      );
      uploadReadyThumbnail = await _createSafeUploadCopy(
        source: finalThumbnailFile,
        prefix: 'feed_thumb',
        tempFiles: tempFiles,
      );
    } catch (e) {
      return failedResponseSnackBar(
          message: 'Failed to prepare video files for upload.');
    }

    // Step 5: Upload video (with compressed retry for HTML/non-JSON/server-false responses)
    Loggers.info('Uploading video...');
    FilePathModel uploadedVideo;
    try {
      uploadedVideo =
          await CommonService.instance.uploadFileGivePath(uploadReadyVideo);
    } catch (e) {
      Loggers.warning('Primary video upload failed: $e');

      if (_shouldRetryCompressedUpload(e)) {
        Loggers.info(
            'Retrying with compressed video due upload parser/server error...');
        XFile? retryCompressedVideo = await MediaPickerHelper.shared
            .compressVideoLowQuality(finalVideoFile.path);

        if (retryCompressedVideo != null &&
            retryCompressedVideo.path.isNotEmpty &&
            File(retryCompressedVideo.path).existsSync()) {
          tempFiles.add(retryCompressedVideo.path);
          finalVideoFile = retryCompressedVideo;
          uploadReadyVideo = await _createSafeUploadCopy(
            source: finalVideoFile,
            prefix: 'feed_video_retry',
            tempFiles: tempFiles,
          );
          updateUploadingProgress(progress: 45);
          try {
            uploadedVideo = await CommonService.instance
                .uploadFileGivePath(uploadReadyVideo);
          } catch (retryError) {
            return failedResponseSnackBar(
                message:
                    'Video upload failed after retry. Please try a shorter video or lower quality.');
          }
        } else {
          return failedResponseSnackBar(
              message:
                  'Video upload failed. Unable to prepare compressed retry file.');
        }
      } else {
        return failedResponseSnackBar(
            message: _resolveUploadFailureMessage(
          e,
          fallback: 'Video upload failed. Please try again.',
        ));
      }
    }

    if (uploadedVideo.status != true ||
        uploadedVideo.data == null ||
        uploadedVideo.data!.isEmpty) {
      Loggers.warning(
          'Video upload API returned invalid response: status=${uploadedVideo.status}, message=${uploadedVideo.message}, data=${uploadedVideo.data}');

      XFile? retryCompressedVideo = await MediaPickerHelper.shared
          .compressVideoLowQuality(finalVideoFile.path);
      if (retryCompressedVideo != null &&
          retryCompressedVideo.path.isNotEmpty &&
          File(retryCompressedVideo.path).existsSync()) {
        tempFiles.add(retryCompressedVideo.path);
        finalVideoFile = retryCompressedVideo;
        uploadReadyVideo = await _createSafeUploadCopy(
          source: finalVideoFile,
          prefix: 'feed_video_retry_status',
          tempFiles: tempFiles,
        );
        updateUploadingProgress(progress: 45);
        try {
          uploadedVideo =
              await CommonService.instance.uploadFileGivePath(uploadReadyVideo);
        } catch (_) {}
      }

      if (uploadedVideo.status != true ||
          uploadedVideo.data == null ||
          uploadedVideo.data!.isEmpty) {
        return failedResponseSnackBar(
            message: uploadedVideo.message?.isNotEmpty == true
                ? uploadedVideo.message
                : 'Video upload failed. Please try a shorter video.');
      }
    }

    Loggers.info('Uploading thumbnail...');
    FilePathModel uploadedThumbnail;
    try {
      uploadedThumbnail =
          await CommonService.instance.uploadFileGivePath(uploadReadyThumbnail);
    } catch (e) {
      deleteFiles(tempFiles);
      return failedResponseSnackBar(
          message: 'Thumbnail upload failed. Please try again.');
    }

    if (uploadedThumbnail.status != true ||
        uploadedThumbnail.data == null ||
        uploadedThumbnail.data!.isEmpty) {
      deleteFiles(tempFiles);
      return failedResponseSnackBar(
          message: uploadedThumbnail.message ??
              'Thumbnail upload failed. Please try again.');
    }

    deleteFiles(tempFiles);
    // Step 6: Check upload success
    if (uploadedVideo.status == false || uploadedThumbnail.status == false) {
      return failedResponseSnackBar(message: uploadedVideo.message);
    }

    updateUploadingProgress(progress: 90);

    // Step 7: Finalize post params and upload
    params[Params.video] = uploadedVideo.data;
    params[Params.thumbnail] = uploadedThumbnail.data;

    Loggers.success('Uploading final video post...');
    try {
      final result =
          await AddPostStoryService.instance.addPostFeedVideo(param: params);

      return result;
    } catch (e) {
      Loggers.error('Exception while uploading video post: $e');
      return failedResponseSnackBar(message: '$e');
    }
  }

  bool _shouldRetryCompressedUpload(Object error) {
    final errorText = error.toString().toLowerCase();
    return errorText.contains('formatexception') ||
        errorText.contains('<!doctype html') ||
        errorText.contains('unexpected character') ||
        errorText.contains('http error') ||
        errorText.contains('413') ||
        errorText.contains('502') ||
        errorText.contains('503') ||
        errorText.contains('504');
  }

  String _resolveUploadFailureMessage(
    Object error, {
    required String fallback,
  }) {
    final normalized = error.toString().replaceFirst('Exception: ', '').trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    if (normalized.length > 260) {
      return '${normalized.substring(0, 260)}...';
    }
    return normalized;
  }

  Future<XFile> _createSafeUploadCopy({
    required XFile source,
    required String prefix,
    required List<String?> tempFiles,
  }) async {
    final sourceFile = File(source.path);
    if (!await sourceFile.exists()) {
      throw Exception('Source file does not exist');
    }

    final ext = _fileExtension(source.path);
    final safePath =
        '$localPath${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final copied = await sourceFile.copy(safePath);
    tempFiles.add(copied.path);
    return XFile(copied.path);
  }

  String _fileExtension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return '';
    }
    return path.substring(dot);
  }

  void updateUploadingProgress({
    required double progress,
  }) {
    this.progress.value = progress;
    dashboardController.onProgress.call(
      PostUploadingProgress(
        uploadType: _lastUploadType,
        progress: progress,
        type: camera_types.CameraScreenType.post,
      ),
    );

    if (progress == 100) {
      _resetUploadingProgressAfterDelay();
    }
  }

  void _resetUploadingProgressAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      dashboardController.onProgress.call(
        PostUploadingProgress(
          uploadType: UploadType.none,
          progress: 0,
          type:
              camera_types.CameraScreenType.post, // or use last type if needed
        ),
      );
    });
  }

  /// Navigate to appropriate destination based on content type
  Future<void> _navigateToCorrectDestination(
      Post post, CreateFeedType createType) async {
    Loggers.info('🧭 Navigating to destination for ${createType.name}');

    // STEP 1: Dispose video player safely (ignore errors)
    try {
      videoPlayerController.value?.pause();
      videoPlayerController.value?.dispose();
      videoPlayerController.value = null;
    } catch (e) {
      // Ignore video player errors during disposal
      Loggers.warning('Video player disposal (ignored): $e');
    }

    // STEP 2: Close screens based on content type (using closeCurrentScreen to avoid snackbar errors)
    if (createType == CreateFeedType.reel && content.value != null) {
      // Close all screens until we reach Dashboard
      // Use Get.until to close all screens until Dashboard
      Get.until((route) => route.settings.name == '/DashboardScreen');
      Loggers.success('🎬 Closed all reel creation screens');
    } else {
      // Close only CreateFeedScreen for feed posts
      final navigator = Get.key.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.pop();
      } else {
        final context = Get.context;
        if (context != null) {
          await Navigator.of(context, rootNavigator: true).maybePop();
        }
      }
      Loggers.success('📰 Closed CreateFeedScreen');
    }

    // STEP 3: Small delay to ensure screens are closed
    await Future.delayed(const Duration(milliseconds: 300));

    // STEP 4: Navigate to profile tab
    if (Get.isRegistered<DashboardScreenController>()) {
      final dashboardController = Get.find<DashboardScreenController>();

      // Navigate to profile tab
      dashboardController.onBottomIndexChanged?.call(4);
      Loggers.success('📍 Navigated to Profile tab');
    }

    // STEP 5: Wait for navigation to complete
    await Future.delayed(const Duration(milliseconds: 400));

    // STEP 6: Switch to correct profile tab
    if (Get.isRegistered<ProfileScreenController>(
        tag: ProfileScreenController.tag)) {
      final profileController =
          Get.find<ProfileScreenController>(tag: ProfileScreenController.tag);

      switch (createType) {
        case CreateFeedType.feed:
          // Switch to posts/feed tab in profile (index 1)
          profileController.selectedTabIndex.value = 1;
          profileController.pageController.jumpToPage(1);
          Loggers.success('📰 Switched to Profile Posts tab (index 1)');
          break;

        case CreateFeedType.reel:
          // Switch to reels tab in profile (index 0)
          profileController.selectedTabIndex.value = 0;
          profileController.pageController.jumpToPage(0);
          Loggers.success('🎬 Switched to Profile Reels tab (index 0)');
          break;
      }
    }
  }

  /// 🎉 Show success message for post upload
  void _showSuccessMessage(Post post, CreateFeedType type) {
    String message;
    Color backgroundColor;
    IconData icon;

    switch (type) {
      case CreateFeedType.reel:
        message = '🎬 Reel uploaded successfully!';
        backgroundColor = Colors.purple.withValues(alpha: 0.9);
        icon = Icons.video_library_rounded;
        break;
      case CreateFeedType.feed:
        if (feedPostType.value == FeedPostType.image) {
          message = '📸 Photo post uploaded successfully!';
          backgroundColor = Colors.green.withValues(alpha: 0.9);
          icon = Icons.photo_library_rounded;
        } else if (feedPostType.value == FeedPostType.video) {
          message = '🎥 Video post uploaded successfully!';
          backgroundColor = Colors.blue.withValues(alpha: 0.9);
          icon = Icons.video_library_rounded;
        } else {
          message = '📝 Text post uploaded successfully!';
          backgroundColor = Colors.orange.withValues(alpha: 0.9);
          icon = Icons.text_fields_rounded;
        }
        break;
    }

    _showStatusMessage(
      title: 'Upload Complete',
      message: message,
      backgroundColor: backgroundColor,
      icon: Icon(icon, color: Colors.white),
      duration: const Duration(seconds: 3),
    );

    Loggers.success('User notified: $message');
  }

  Future<PostModel?> failedResponseSnackBar({String? message}) async {
    _lastUploadType = UploadType.error;
    updateUploadingProgress(progress: 100);

    final errorMessage = (message == null || message.trim().isEmpty)
        ? 'Upload failed. Please try again.'
        : message.trim();
    _lastUploadErrorMessage = errorMessage;

    _showStatusMessage(
      title: 'Upload Failed',
      message: errorMessage,
      backgroundColor: Colors.red.withValues(alpha: 0.9),
      icon: const Icon(Icons.error_outline, color: Colors.white),
      duration: const Duration(seconds: 3),
    );

    return null;
  }

  void _showStatusMessage({
    required String title,
    required String message,
    required Color backgroundColor,
    Widget? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      final context = Get.key.currentContext ?? Get.context;
      if (context == null) {
        Loggers.warning('Status message skipped: context unavailable');
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        Loggers.warning('Status message skipped: messenger unavailable');
        return;
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: backgroundColor,
            duration: duration,
            margin: const EdgeInsets.all(16),
            content: Row(
              children: [
                if (icon != null) ...[
                  icon,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    '$title\n$message',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    } catch (e) {
      Loggers.warning('Status message failed: $e');
    }
  }

  Future<void> deleteFiles(List<String?> paths) async {
    await Future(() async {
      for (final path in paths.whereType<String>()) {
        final file = File(path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            Loggers.error('❌ Failed to delete: $path — $e');
          }
        }
      }
      Loggers.info('📁 Deleted files: $paths');
    });
  }

  onLocationTap(Places place) {
    selectedLocation.value = place;
  }

  onMediaTap(FeedPostType type) {
    commentHelper.detectableTextFocusNode.unfocus();
    switch (type) {
      case FeedPostType.image:
        selectImages();
        break;
      case FeedPostType.text:
        break;
      case FeedPostType.video:
        pickVideo();
        break;
    }
  }

  Future<void> selectImages() async {
    final int remainingSlots =
        setting.value?.maxImagesPerPost ?? AppRes.imageLimit - images.length;

    if (remainingSlots >= 2) {
      final List<XFile> imageFiles =
          await MediaPickerHelper.shared.multipleImages(limit: remainingSlots);

      images.addAll(imageFiles.map(
        (file) => ImageWithFilter(media: file, thumbnail: file),
      ));
    } else {
      final XFile? imageFile =
          await MediaPickerHelper.shared.pickImage(source: ImageSource.gallery);

      if (imageFile != null) {
        images.add(ImageWithFilter(media: imageFile, thumbnail: imageFile));
      }
    }
    if (images.isNotEmpty) {
      feedPostType.value = FeedPostType.image;
    }
  }

  void onDeleteSelectedImages() {
    if (images.isNotEmpty) {
      // Remove the selected file
      images.removeAt(selectedImageIndex.value);
      images.refresh();

      // Adjust the selected index only if files are not empty after removal
      if (images.isNotEmpty) {
        if (selectedImageIndex.value >= images.length) {
          selectedImageIndex.value = images.length - 1;
        }
      } else {
        // Reset index to 0 if all files are removed
        selectedImageIndex.value = 0;
        feedPostType.value = FeedPostType.text;
      }
    }
  }

  pickVideo() async {
    MediaFile? file =
        await MediaPickerHelper.shared.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      video.value =
          ImageWithFilter(media: file.file, thumbnail: file.thumbNail);
      videoPlayerController.value =
          VideoPlayerController.file(File(file.file.path))
            ..initialize().then((value) => videoPlayerController.refresh());
    }
    feedPostType.value = FeedPostType.video;
  }

  void onChangeReelCover() async {
    XFile? file =
        await MediaPickerHelper.shared.pickImage(source: ImageSource.gallery);
    if (file != null) {
      Uint8List bytes = await file.readAsBytes();
      content.update((val) {
        val?.thumbnailBytes = bytes;
        val?.thumbNail = file.path;
      });
    }
  }

  void selectedVideoDelete() {
    video.value = null;
    videoPlayerController.value?.dispose();
    feedPostType.value = FeedPostType.text;
  }
}

enum FeedTagType {
  mention(AssetRes.icAt, LKey.mention),
  hashtag(AssetRes.icHashtag, LKey.hashtags),
  location(AssetRes.icLocation, LKey.location);

  final String image;
  final String titleKey;

  const FeedTagType(this.image, this.titleKey);

  String get title => titleKey.tr;
}

enum FeedPostType { image, text, video }

class ReelData {
  XFile? videoFile;
  XFile? thumbnailFile;
  Uint8List? thumbnailBytes;
  Color? bgColor;
  SelectedMusic? selectedMusic;
  int? videoDurationMs;
  Filters? selectedFilter;

  ReelData({
    required this.videoFile,
    required this.thumbnailFile,
    this.thumbnailBytes,
    this.videoDurationMs,
    this.bgColor,
    this.selectedFilter,
    this.selectedMusic,
  });

  ReelData copyWith({
    XFile? videoFile,
    XFile? thumbnailFile,
    Uint8List? thumbnailBytes,
    Color? bgColor,
    SelectedMusic? selectedMusic,
    int? audioStartDurationMs,
    int? videoDurationMs,
    Filters? selectedFilter,
  }) {
    return ReelData(
        videoFile: videoFile ?? this.videoFile,
        thumbnailFile: thumbnailFile ?? this.thumbnailFile,
        thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
        bgColor: bgColor ?? this.bgColor,
        selectedMusic: selectedMusic ?? this.selectedMusic,
        videoDurationMs: videoDurationMs ?? this.videoDurationMs,
        selectedFilter: selectedFilter ?? this.selectedFilter);
  }
}

class ImageWithFilter {
  XFile media;
  XFile thumbnail;
  List<double> colorFilter;

  ImageWithFilter(
      {required this.media,
      this.colorFilter = defaultFilter,
      required this.thumbnail});
}

enum ImageWithFilterType {
  video,
  image;
}
