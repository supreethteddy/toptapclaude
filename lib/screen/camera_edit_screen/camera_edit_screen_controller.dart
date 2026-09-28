import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/model/drawing/draw_stroke.dart';
import 'package:image_picker/image_picker.dart';
import 'package:retrytech_plugin/retrytech_plugin.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/functions/generate_color.dart';
import 'package:shortzz/common/functions/media_picker_helper.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/screenshot_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/sight_engin/sight_engine_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/post_story/story/story_model.dart';
// Old camera imports - keeping for reference
// import 'package:shortzz/screen/camera_screen/camera_screen.dart';
// import 'package:shortzz/screen/camera_screen/camera_screen_controller.dart';
// New camera types import
import 'package:shortzz/screen/camera_screen/camera_types.dart'
    as camera_types;
import 'package:shortzz/screen/color_filter_screen/widget/color_filtered.dart';
import 'package:shortzz/screen/create_feed_screen/create_feed_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/feed_screen/feed_screen_controller.dart';
import 'package:shortzz/screen/music_sheet/music_sheet.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet.dart';
import 'package:shortzz/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:video_player/video_player.dart';
import 'package:shortzz/model/sticker/sticker_model.dart';
import 'package:shortzz/model/sticker/positioned_sticker.dart';
import 'package:shortzz/screen/sticker_sheet/sticker_sheet.dart';

import 'text_story/story_text_view_controller.dart';

class CameraEditScreenController extends BaseController {
  Rx<camera_types.PostStoryContent> content;
  camera_types.CameraScreenType screenType;

  // Stickers
  RxList<PositionedSticker> stickers =
      <PositionedSticker>[].obs;
  Rx<PositionedSticker?> selectedSticker =
      Rx<PositionedSticker?>(null);
  RxBool hideStickerControls =
      false.obs; // Hide borders/buttons during screenshot

  // Drawing
  RxBool isDrawingMode = false.obs;
  RxList<DrawStroke> drawingStrokes = <DrawStroke>[].obs;
  RxList<DrawStroke> redoStrokes = <DrawStroke>[].obs;
  Rx<Color> selectedDrawColor = Colors.white.obs;
  Rx<double> brushSize = 6.0.obs;
  RxBool isEraser = false.obs;

  CameraEditScreenController(this.content,
      {this.screenType =
          camera_types.CameraScreenType.story}) {
    print(
        '🎯 DEBUG: CameraEditScreenController initialized with screenType: $screenType');
  }

  final _dashboardController =
      Get.find<DashboardScreenController>();
  final _retrytechPlugin = RetrytechPlugin();
  UploadType _lastUploadType = UploadType.none;

  Rx<List<double>> selectedFilter = Rx([]);
  Rx<VideoPlayerController?> videoPlayerController =
      Rx<VideoPlayerController?>(null);
  List<LinearGradient> storyGradientColor =
      GenerateColor.instance.gradientList;

  PlayerController audioPlayer = PlayerController();

  RxInt selectedFilterIndex = 0.obs;
  RxInt currentStoryDurationIndex = 0.obs;
  RxInt selectedBgIndex = 0.obs;
  int selectStorySecond = AppRes.storyDurations.first;

  Timer? _timer;
  bool _isRestartingPlayback = false;
  DateTime? _lastCompletionHandledAt;

  RxBool isFilterShow = false.obs;
  RxBool isMergingVideo = false.obs;
  RxBool isStoryUploading = false.obs;
  bool hasAudio = true;

  VoidCallback? onNewTexFieldAdd;

  String localPath = '';

  @override
  Future<void> onReady() async {
    super.onReady();
    selectedFilter.value = content.value.filter;
    _initVideoController();
    localPath = await PlatformPathExtension.localPath;
  }

  @override
  void onClose() {
    super.onClose();
    _disposeControllers();
  }

  void changedFilter(List<double> filter) {
    selectedFilter.value = filter;
  }

  Future<void> addStory(
      {required String content,
      String? thumbnail,
      required camera_types.PostStoryContentType type,
      required int duration,
      int? musicId,
      bool allowSizeRetry = true}) async {
    try {
      if (content.isEmpty || !File(content).existsSync()) {
        Loggers.error(
            '[Story Upload] Invalid content path for upload: $content');
        failedResponseSnackBar('Story media file is missing.');
        return;
      }

      if (type == camera_types.PostStoryContentType.storyVideo) {
        if (thumbnail == null ||
            thumbnail.isEmpty ||
            !File(thumbnail).existsSync()) {
          Loggers.error(
              '[Story Upload] Invalid thumbnail path for video story: $thumbnail');
          failedResponseSnackBar('Story thumbnail is missing.');
          return;
        }
      }

      StoryModel? response =
          await PostService.instance.createStory(files: {
        Params.content: [XFile(content)],
        if (type ==
            camera_types.PostStoryContentType.storyVideo)
          Params.thumbnail: [XFile(thumbnail!)]
      }, param: {
        Params.type: type ==
                camera_types.PostStoryContentType.storyVideo
            ? 1
            : 0,
        Params.duration: duration,
        if (musicId != -1) Params.soundID: musicId
      });
      Loggers.info(response.message);
      if (response.status == true &&
          response.data != null) {
        addStoryResponse(response.data!);
      } else {
        final responseMessage = response.message ?? '';
        Loggers.error(
            '[Story Upload] createStory failed. status=${response.status}, message=$responseMessage, type=$type, duration=$duration');

        if (allowSizeRetry &&
            type == camera_types.PostStoryContentType.storyVideo &&
            _isPayloadTooLargeError(responseMessage)) {
          await _retryLargeStoryVideoUpload(
            content: content,
            thumbnail: thumbnail,
            duration: duration,
            musicId: musicId,
          );
          return;
        }

        failedResponseSnackBar(responseMessage.isNotEmpty
            ? responseMessage
            : 'The content failed to upload.');
      }
    } catch (e, st) {
      Loggers.error(
          '[Story Upload] createStory exception: $e\n$st');

      if (allowSizeRetry &&
          type == camera_types.PostStoryContentType.storyVideo &&
          _isPayloadTooLargeError('$e')) {
        await _retryLargeStoryVideoUpload(
          content: content,
          thumbnail: thumbnail,
          duration: duration,
          musicId: musicId,
        );
        return;
      }

      failedResponseSnackBar('The content failed to upload.');
    }
  }

  bool _isPayloadTooLargeError(String rawError) {
    final error = rawError.toLowerCase();
    return error.contains('http 413') ||
        error.contains('posttoolargeexception') ||
        error.contains('too large');
  }

  Future<void> _retryLargeStoryVideoUpload({
    required String content,
    String? thumbnail,
    required int duration,
    int? musicId,
  }) async {
    Loggers.warning(
        '[Story Upload] Payload too large. Retrying with compressed video...');
    updateUploadingProgress(progress: 55);

    final compressedVideo =
        await MediaPickerHelper.shared.compressVideoLowQuality(content);
    if (compressedVideo == null ||
        compressedVideo.path.isEmpty ||
        !File(compressedVideo.path).existsSync()) {
      failedResponseSnackBar(
          'Video is too large. Please trim or compress and try again.');
      return;
    }

    String retryThumbnail = thumbnail ?? '';
    try {
      final thumb = await MediaPickerHelper.shared
          .extractThumbnail(videoPath: compressedVideo.path);
      if (thumb.path.isNotEmpty && File(thumb.path).existsSync()) {
        retryThumbnail = thumb.path;
      }
    } catch (e) {
      Loggers.warning(
          '[Story Upload] Failed to regenerate thumbnail for compressed video: $e');
    }

    await addStory(
      content: compressedVideo.path,
      thumbnail: retryThumbnail,
      type: camera_types.PostStoryContentType.storyVideo,
      duration: duration,
      musicId: musicId,
      allowSizeRetry: false,
    );
  }

  void addStoryResponse(Story story) {
    story.user = SessionManager.instance.getUser();

    // DEBUG: Print screen type to verify correct behavior
    print(
        '🔍 addStoryResponse called with screenType: $screenType');
    print(
        '🔍 Story will be added to ProfileScreenController (always)');
    print(
        '🔍 Story will be added to FeedScreenController: ${screenType == camera_types.CameraScreenType.post}');

    // Always update ProfileScreenController for stories
    Get.isRegistered<ProfileScreenController>(
            tag: ProfileScreenController.tag)
        ? Get.find<ProfileScreenController>(
                tag: ProfileScreenController.tag)
            .onAddStory(story)
        : null;

    // Only add to feed if this is a POST (feed content), not a STORY
    if (screenType == camera_types.CameraScreenType.post) {
      print(
          '✅ Adding story to FeedScreenController (screenType is POST)');
      Get.isRegistered<FeedScreenController>()
          ? Get.find<FeedScreenController>()
              .onAddStory(story)
          : null;
    } else {
      print(
          '🚫 NOT adding story to FeedScreenController (screenType is STORY)');
    }

    _lastUploadType = UploadType.finish;
    updateUploadingProgress(progress: 100);
    isStoryUploading.value = false;
    _closeUploadFlowAfterSuccess();
  }

  void onDiscard() {
    Get.bottomSheet(ConfirmationSheet(
        title: LKey.discardEditsTitle.tr,
        description: LKey.discardEditsMessage.tr,
        onTap: Get.back));
  }

  void onFilterToggle() {
    isFilterShow.toggle();
  }

  void _initVideoController() async {
    if ([
      camera_types.PostStoryContentType.storyImage,
      camera_types.PostStoryContentType.storyText
    ].contains(content.value.type)) {
      SelectedMusic? sound = content.value.sound;
      if (sound != null && sound.downloadedURL != null) {
        String audioPath = sound.downloadedURL ?? '';
        await _prepareAudioPlayer(
            audioPath: audioPath,
            milliSecond: sound.audioStartMS);
        _playAudioOnly();
      }
      return;
    }

    videoPlayerController.value =
        VideoPlayerController.file(
            File(content.value.content ?? ''));

    await videoPlayerController.value?.initialize();

    hasAudio = await RetrytechPlugin.shared.hasAudio(
            inputPath: content.value.content ?? '') ??
        true;
    videoPlayerController.refresh();
    // Keep manual loop handling for better video+audio sync.
    videoPlayerController.value?.setLooping(false);
    content.update((val) => val?.duration =
        videoPlayerController
                .value?.value.duration.inSeconds ??
            0);

    SelectedMusic? sound = content.value.sound;

    if (sound?.downloadedURL != null) {
      String audioPath = sound?.downloadedURL ?? '';
      await _prepareAudioPlayer(
          audioPath: audioPath,
          milliSecond: sound?.audioStartMS);
      videoPlayerController.value?.setVolume(0.0);
    }
    _startPlayback();
    _setVideoController(videoPlayerController.value!);
  }

  void _setVideoController(
      VideoPlayerController controller) {
    controller.removeListener(
        _handleVideoCompletion); // Remove if already exists
    controller.addListener(_handleVideoCompletion);
  }

  /// Listener to handle video playback completion and restart logic
  void _handleVideoCompletion() {
    final controller = videoPlayerController.value;
    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    if (_isRestartingPlayback) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) {
      return;
    }

    final isVideoComplete =
        (duration - position).inMilliseconds.abs() <
            500; // Allow small margin (e.g., 500ms)

    if (!isVideoComplete) {
      return;
    }
    final now = DateTime.now();
    if (_lastCompletionHandledAt != null &&
        now.difference(_lastCompletionHandledAt!).inMilliseconds < 900) {
      return;
    }
    _lastCompletionHandledAt = now;
    Loggers.info('_handleVideoCompletion');
    switch (content.value.type) {
      case camera_types.PostStoryContentType.reel:
      case camera_types.PostStoryContentType.storyVideo:
        _restartVideoAndAudio();
        break;
      case camera_types.PostStoryContentType.storyText:
      case camera_types.PostStoryContentType.storyImage:
        _playAudioOnly();
        break;
    }
  }

  /// Restarts video and audio from the beginning
  Future<void> _restartVideoAndAudio() async {
    if (_isRestartingPlayback) return;
    _isRestartingPlayback = true;
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      await _pausePlayback(); // Pause first for clean reset
      await _resetPlaybackPositions(); // Seek both to start
      _startPlayback(); // Resume playing
      Loggers.info(
        '▶️ Restarting — Video: ${videoPlayerController.value?.value.duration}, '
        'Audio Start: ${Duration(milliseconds: content.value.sound?.audioStartMS ?? 0)}',
      );
    } finally {
      _isRestartingPlayback = false;
    }
  }

  /// Starts both video and audio playback
  void _startPlayback() {
    videoPlayerController.value?.play();
    audioPlayer.startPlayer(forceRefresh: false);
    Loggers.warning('▶️ Video and Audio Playback Started');
  }

  /// Pauses both video and audio playback
  Future<void> _pausePlayback() async {
    videoPlayerController.value?.pause();
    if (content.value.sound != null) {
      audioPlayer.pausePlayer();
    }
    Loggers.warning('⏸️ Video and Audio Playback Paused');
  }

  /// Resets video and audio position to the beginning
  Future<void> _resetPlaybackPositions() async {
    await videoPlayerController.value
        ?.seekTo(Duration.zero);
    final startMs = content.value.sound?.audioStartMS ?? 0;
    // await audioPlayer.pausePlayer();
    if (content.value.sound != null) {
      audioPlayer.seekTo(startMs);
    }
    Loggers.info('✂️ Reset Play back');
  }

  /// Toggles between playing and pausing
  void onPlayPauseToggle() {
    final isPlaying =
        videoPlayerController.value?.value.isPlaying ??
            false;
    isPlaying ? _pausePlayback() : _startPlayback();
  }

  void _disposeControllers() {
    _timer?.cancel();
    _isRestartingPlayback = false;
    audioPlayer.release();
    audioPlayer.dispose();
    videoPlayerController.value
        ?.removeListener(_handleVideoCompletion);
    videoPlayerController.value?.dispose();
    videoPlayerController.value = null;
  }

  /// Starts looping audio playback for image/text story types
  void _playAudioOnly() {
    if (content.value.sound?.music == null) return;

    audioPlayer.startPlayer();
    _timer = Timer(
      Duration(seconds: selectStorySecond),
      () async {
        await _pauseAudioOnly();
        _playAudioOnly();
      },
    );
  }

  /// Pauses audio and resets to the defined start position
  Future<void> _pauseAudioOnly() async {
    _timer?.cancel();
    await audioPlayer.pausePlayer();
    await audioPlayer
        .seekTo(content.value.sound?.audioStartMS ?? 0);
  }

  /// Toggles video player volume between mute and full volume
  void toggleVideoVolume() {
    final controller = videoPlayerController.value;
    if (controller == null) return;

    final isMuted = controller.value.volume == 0.0;
    controller.setVolume(isMuted ? 1.0 : 0.0);
  }

  Future<void> handleContentUpload() async {
    final currentContent = content.value;
    if (currentContent.type ==
        camera_types.PostStoryContentType.reel) {
      final videoPath = currentContent.content ?? '';
      if (videoPath.isNotEmpty) {
        SightEngineService.shared.checkVideoInSightEngine(
          xFile: XFile(videoPath),
          duration: videoPlayerController
                  .value?.value.duration.inSeconds ??
              0,
          completion: handleReelUpload,
        );
      } else {
        showSnackBar(LKey.videoPathNotFound.tr);
      }
    } else if ([
      camera_types.PostStoryContentType.storyText,
      camera_types.PostStoryContentType.storyImage,
      camera_types.PostStoryContentType.storyVideo,
    ].contains(currentContent.type)) {
      handleStoryUpload();
    }
  }

  /// Entry point for post upload after moderation check
  Future<void> handleReelUpload() async {
    final hasAudio = content.value.sound != null;
    isMergingVideo.value = true;

    if (hasAudio) {
      await _applyFilterAndAudioToReel();
    } else {
      await _applyFilterOnlyToReel();
    }
  }

  /// Applies only filters (no external audio)
  Future<void> _applyFilterOnlyToReel() async {
    Loggers.info(
        '[Reel Upload] Processing video without external audio');

    final post = content.value;
    final inputPath = post.content ?? '';
    final outputPath = '${localPath}filter_video.mp4';
    String finalPath = inputPath;

    if (!listEquals(
        selectedFilter.value, filters.first.colorFilter)) {
      Loggers.info('Filter Applying..');
      try {
        final result = await _retrytechPlugin
            .applyFilterAndAudioToVideo(
          inputPath: inputPath,
          outputPath: outputPath,
          filterValues: selectedFilter.value,
          shouldBothMusics: true,
        );

        if (result == true) {
          finalPath = outputPath;
        } else {
          Loggers.error(
              '[Reel Upload] Failed to apply filter');
          return;
        }
      } catch (e) {
        Loggers.error(
            '[Reel Upload] Filter application error: $e');
        return;
      } finally {
        isMergingVideo.value = false;
      }
    } else {
      Loggers.info('Filter not applying..');
      isMergingVideo.value = false;
    }

    _pausePlayback();
    await _goToCreateFeedScreen(finalPath);
    _restartVideoAndAudio();
  }

  /// Applies filter + audio overlay
  Future<void> _applyFilterAndAudioToReel() async {
    Loggers.info(
        '[Reel Upload] Processing video with audio');

    final post = content.value;
    final inputPath = post.content;
    final audioPath = post.sound?.downloadedURL;
    final outputPath =
        '${localPath}merge_audio_filter_video.mp4';
    String finalPath = inputPath ?? '';
    final List<double> filtersValue = listEquals(
            selectedFilter.value,
            camera_types.defaultFilter)
        ? []
        : selectedFilter.value;
    final mixOriginalAudio =
        videoPlayerController.value?.value.volume != 0.0;
    final audioStartTimeInMS = double.tryParse(
            '${post.sound?.audioStartMS ?? 0}') ??
        0.0;

    if (inputPath == null || audioPath == null) {
      Loggers.error(
          '[Reel Upload] Missing input or audio path');
      return;
    }

    try {
      final result =
          await _retrytechPlugin.applyFilterAndAudioToVideo(
        inputPath: inputPath,
        outputPath: outputPath,
        shouldBothMusics: mixOriginalAudio,
        filterValues: filtersValue,
        audioPath: audioPath,
        audioStartTimeInMS: audioStartTimeInMS,
      );

      if (result == true) {
        finalPath = outputPath;
      } else {
        Loggers.error(
            '[Reel Upload] Filter/audio merge failed');
        return;
      }
    } catch (e) {
      Loggers.error(
          '[Reel Upload] Filter/audio merge error: $e');
      return;
    } finally {
      isMergingVideo.value = false;
    }

    _pausePlayback();
    await _goToCreateFeedScreen(finalPath);
    _restartVideoAndAudio();
  }

  /// Extracts thumbnail and navigates to the CreateFeed screen for reels
  Future<void> _goToCreateFeedScreen(
      String videoFilePath) async {
    try {
      // Extract thumbnail image and byte data from video
      final Uint8List? thumbnailBytes =
          await MediaPickerHelper.shared
              .extractThumbnailByte(
                  videoPath: videoFilePath);

      final XFile thumbnailFile = await MediaPickerHelper
          .shared
          .extractThumbnail(videoPath: videoFilePath);

      // Prepare content model for the next screen
      final camera_types.PostStoryContent reelContent =
          camera_types.PostStoryContent(
              type: camera_types.PostStoryContentType.reel,
              content: videoFilePath,
              thumbNail: thumbnailFile.path,
              thumbnailBytes: thumbnailBytes,
              filter: selectedFilter.value,
              duration: content.value.duration,
              sound: content.value.sound,
              bgGradient: content.value.bgGradient,
              hasAudio: hasAudio);

      // Stop any loading indicators
      isMergingVideo.value = false;

      // Navigate to the CreateFeed screen with reel content
      await Get.to(() => CreateFeedScreen(
            createType: CreateFeedType.reel,
            content: reelContent,
          ));
    } catch (e) {
      Loggers.error(
          'Failed to navigate to reel composer: $e');
      isMergingVideo.value = false;
    }
  }

  Future<void> handleStoryUpload() async {
    if (isStoryUploading.value) {
      Loggers.warning(
          '[Story Upload] Upload already in progress, ignoring duplicate tap.');
      return;
    }

    isStoryUploading.value = true;
    final story = content.value;
    final filePath = story.content ?? '';
    final isTextOrImage = [
      camera_types.PostStoryContentType.storyImage,
      camera_types.PostStoryContentType.storyText
    ].contains(story.type);
    final duration = isTextOrImage
        ? selectStorySecond
        : story.duration ?? 0;

    _lastUploadType = UploadType.uploading;
    if (story.type ==
        camera_types.PostStoryContentType.storyVideo) {
      await _processVideoStory(filePath, duration);
    } else {
      await _processImageOrTextStory(duration);
    }
  }

  /// Handles video story: moderation, filtering, music overlay
  Future<void> _processVideoStory(
      String inputFile, int storyDuration) async {
    final story = content.value;
    final outputPath = '${localPath}video_story.mp4';
    bool moderationPassed = false;

    Loggers.info(
        '[Story Upload] Checking moderation for video...');

    await SightEngineService.shared.checkVideoInSightEngine(
      xFile: XFile(inputFile),
      duration: storyDuration,
      completion: () async {
        moderationPassed = true;
        Loggers.info(
            '[Story Upload] Moderation completed.');
        updateUploadingProgress(progress: 20);

        String finalVideoPath = inputFile;
        bool hasUserVoice =
            videoPlayerController.value?.value.volume !=
                0.0;
        List<double> filtersValue = listEquals(
                selectedFilter.value,
                filters.first.colorFilter)
            ? []
            : selectedFilter.value;
        String? audioPath = story.sound?.downloadedURL;
        double audioStartMS = double.tryParse(
                '${story.sound?.audioStartMS ?? 0}') ??
            0.0;
        // Apply filters/music if needed
        if (audioPath != null) {
          try {
            bool? result = await _retrytechPlugin
                .applyFilterAndAudioToVideo(
                    inputPath: inputFile,
                    outputPath: outputPath,
                    shouldBothMusics: hasUserVoice,
                    filterValues: filtersValue,
                    audioPath: audioPath,
                    audioStartTimeInMS: audioStartMS);

            if (result == true) finalVideoPath = outputPath;
          } catch (e) {
            Loggers.error(
                '[Story Upload] Failed to apply filter/audio: $e');
            failedResponseSnackBar();
            return;
          }
        }

        String thumbPath = story.thumbNail ?? '';
        try {
          final thumbFile = File(thumbPath);
          if (thumbPath.isEmpty || !thumbFile.existsSync()) {
            final thumbnail = await MediaPickerHelper.shared
                .extractThumbnail(videoPath: finalVideoPath);
            thumbPath = thumbnail.path;
          }
        } catch (e) {
          Loggers.error(
              '[Story Upload] Failed to prepare video thumbnail: $e');
          failedResponseSnackBar(
              'Failed to prepare story thumbnail.');
          return;
        }

        updateUploadingProgress(progress: 90);

        try {
          await addStory(
              content: finalVideoPath,
              duration: storyDuration,
              type: camera_types
                  .PostStoryContentType.storyVideo,
              musicId: story.sound?.music?.id ?? -1,
              thumbnail: thumbPath);
        } catch (e) {
          Loggers.error(
              '❌ Error posting image/text story: $e');
          failedResponseSnackBar('The content failed to upload.');
        } finally {
          isMergingVideo.value = false;
        }
      },
    );

    if (!moderationPassed &&
        isStoryUploading.value &&
        _lastUploadType == UploadType.uploading) {
      isStoryUploading.value = false;
    }
  }

  /// Handles image/text story: moderation, screenshot, optional music or filter
  Future<void> _processImageOrTextStory(
      int storyDuration) async {
    final story = content.value;
    final controller = Get.find<StoryTextViewController>();
    bool moderationPassed = false;
    showLoader();

    // Hide sticker controls (borders/buttons) before screenshot
    hideStickerControls.value = true;
    await Future.delayed(const Duration(
        milliseconds: 100)); // Wait for UI update

    final screenshot =
        await ScreenshotManager.captureScreenshot(
            controller.previewContainer);

    // Show controls again after screenshot
    hideStickerControls.value = false;

    if (screenshot == null) {
      stopLoader();
      isStoryUploading.value = false;
      return Loggers.error(
          '❌ Failed to capture screenshot');
    }

    final imagePath = screenshot.path;
    final value = await MediaPickerHelper.shared.compressImage(
        screenshot.path, '${localPath}compress_images.jpg');
    stopLoader();
    if (value == null) {
      isStoryUploading.value = false;
      return Loggers.error('❌ Failed to compress image');
    }

    await SightEngineService.shared.checkImagesInSightEngine(
      xFiles: [value],
      completion: () async {
        moderationPassed = true;
        Loggers.info(
            '[Story Upload] Moderation completed.');
        updateUploadingProgress(progress: 20);

        final audioPath = story.sound?.downloadedURL;
        final audioStartMS = double.tryParse(
                '${story.sound?.audioStartMS ?? 0.0}') ??
            0.0;
        final musicId = story.sound?.music?.id ?? -1;
        final videoPath =
            '${localPath}image_to_video.mp4';

        if (audioPath != null) {
          Loggers.info(
              '🎵 Music found, generating video from image...');

          bool? success =
              await _retrytechPlugin.createVideoFromImage(
                  inputPath: imagePath,
                  outputPath: videoPath,
                  audioStartTimeInMS: audioStartMS,
                  audioPath: audioPath,
                  videoTotalDurationInSec:
                      storyDuration.toDouble());

          if (success != true) {
            Loggers.error(
                '[Story Upload] Failed to generate story video from image.');
            failedResponseSnackBar(
                'Failed to prepare story with music.');
            return;
          }

          updateUploadingProgress(progress: 90);

          await addStory(
              duration: storyDuration,
              content: videoPath,
              type: camera_types
                  .PostStoryContentType.storyVideo,
              musicId: musicId,
              thumbnail: imagePath);
        } else {
          updateUploadingProgress(progress: 90);
          await addStory(
              duration: storyDuration,
              content: imagePath,
              type: camera_types
                  .PostStoryContentType.storyImage,
              musicId: -1);
        }
      },
    );

    if (!moderationPassed &&
        isStoryUploading.value &&
        _lastUploadType == UploadType.uploading) {
      isStoryUploading.value = false;
    }
  }

  void updateUploadingProgress({required double progress}) {
    _dashboardController.onProgress.call(
      PostUploadingProgress(
        uploadType: _lastUploadType,
        progress: progress,
        type: screenType,
      ),
    );

    if (progress == 100) {
      _resetUploadingProgressAfterDelay();
    }
  }

  void _resetUploadingProgressAfterDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      _dashboardController.onProgress.call(
        PostUploadingProgress(
          uploadType: UploadType.none,
          progress: 0,
          type: screenType, // Use the actual screen type
        ),
      );
    });
  }

  Future<void> failedResponseSnackBar([String? message]) async {
    _lastUploadType = UploadType.error;
    updateUploadingProgress(progress: 100);
    isStoryUploading.value = false;
    if ((message ?? '').trim().isNotEmpty) {
      showSnackBar(message);
    }
    return;
  }

  void _closeUploadFlowAfterSuccess() {
    if (Get.isDialogOpen == true) {
      Get.back();
    }

    var pops = 0;
    while (pops < 4 && (Get.key.currentState?.canPop() ?? false)) {
      Get.back();
      pops++;
    }
  }

  void onMusicDelete() {
    content.update((val) => val?.sound = null);
    audioPlayer.stopPlayer();
    audioPlayer.release();
    videoPlayerController.value?.setVolume(1);
  }

  // ========== STICKER METHODS ==========

  /// Open sticker selection bottom sheet
  Future<void> onStickerTap() async {
    final StickerModel? sticker =
        await Get.bottomSheet<StickerModel>(
      StickerSheet(),
      isScrollControlled: true,
    );

    if (sticker != null) {
      addSticker(sticker);
    }
  }

  /// Add a new sticker to the canvas
  void addSticker(StickerModel sticker) {
    final positionedSticker = PositionedSticker(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sticker: sticker,
      x: 100, // Default position - center-ish
      y: 200,
      width: 150,
      height: 150,
      scale: 1.0,
      rotation: 0.0,
    );
    stickers.add(positionedSticker);
    selectedSticker.value = positionedSticker;
  }

  /// Update sticker position/size/rotation
  void updateSticker(PositionedSticker updatedSticker) {
    final index = stickers
        .indexWhere((s) => s.id == updatedSticker.id);
    if (index != -1) {
      stickers[index] = updatedSticker;
    }
  }

  /// Select a sticker
  void selectSticker(PositionedSticker? sticker) {
    selectedSticker.value = sticker;
  }

  /// Delete selected sticker
  void deleteSelectedSticker() {
    if (selectedSticker.value != null) {
      stickers.removeWhere(
          (s) => s.id == selectedSticker.value!.id);
      selectedSticker.value = null;
    }
  }

  /// Delete specific sticker
  void deleteSticker(String stickerId) {
    stickers.removeWhere((s) => s.id == stickerId);
    if (selectedSticker.value?.id == stickerId) {
      selectedSticker.value = null;
    }
  }

  // ========== DRAWING METHODS ==========

  /// Toggle drawing mode
  void toggleDrawingMode() {
    isDrawingMode.value = !isDrawingMode.value;
    if (isDrawingMode.value) {
      // Deselect stickers when entering drawing mode
      selectedSticker.value = null;
    }
  }

  /// Add completed stroke to drawing
  void addDrawingStroke(DrawStroke stroke) {
    drawingStrokes.add(stroke);
    // Clear redo history when new stroke is added
    redoStrokes.clear();
  }

  /// Undo last drawing stroke
  void undoDrawingStroke() {
    if (drawingStrokes.isNotEmpty) {
      final lastStroke = drawingStrokes.removeLast();
      redoStrokes.add(lastStroke);
      drawingStrokes.refresh();
      redoStrokes.refresh();
    }
  }

  /// Redo drawing stroke
  void redoDrawingStroke() {
    if (redoStrokes.isNotEmpty) {
      final stroke = redoStrokes.removeLast();
      drawingStrokes.add(stroke);
      drawingStrokes.refresh();
      redoStrokes.refresh();
    }
  }

  /// Clear all drawings
  void clearAllDrawings() {
    drawingStrokes.clear();
    redoStrokes.clear();
  }

  /// Exit drawing mode
  void exitDrawingMode() {
    isDrawingMode.value = false;
    isEraser.value = false;
  }

  /// Toggle eraser mode
  void toggleEraser() {
    isEraser.value = !isEraser.value;
  }

  /// Set drawing color
  void setDrawingColor(Color color) {
    selectedDrawColor.value = color;
    if (isEraser.value) {
      isEraser.value =
          false; // Turn off eraser when selecting color
    }
  }

  /// Set brush size
  void setBrushSize(double size) {
    brushSize.value = size;
  }

  /// Opens the music selection sheet and applies the selected music to the story
  Future<void> handleMusicSelection(
      {SelectedMusic? initialMusic}) async {
    final isTextOrImage = [
      camera_types.PostStoryContentType.storyImage,
      camera_types.PostStoryContentType.storyText,
    ].contains(content.value.type);

    // Pause appropriate media before opening selection
    isTextOrImage ? _pauseAudioOnly() : _pausePlayback();

    final duration = isTextOrImage
        ? selectStorySecond
        : content.value.duration ?? 0;

    videoPlayerController.value?.pause();

    final SelectedMusic? selectedMusic = initialMusic != null
        ? await Get.bottomSheet<SelectedMusic?>(
            SelectedMusicSheet(
                selectedMusic: initialMusic,
                totalVideoSecond: duration),
            isScrollControlled: true,
          )
        : await Get.to<SelectedMusic?>(
            () => MusicSheet(videoDurationInSecond: duration),
          );

    // Handle result
    await _processSelectedMusic(
        selectedMusic, isTextOrImage);
  }

  /// Shared logic to apply selected music and resume playback
  Future<void> _processSelectedMusic(
      SelectedMusic? selectedMusic,
      bool isTextOrImage) async {
    if (selectedMusic == null) {
      isTextOrImage ? _playAudioOnly() : _startPlayback();
      return;
    }

    content.update((val) => val?.sound = selectedMusic);

    final audioUrl = selectedMusic.downloadedURL;
    final startMs = selectedMusic.audioStartMS ?? 0;

    if (audioUrl != null) {
      await _prepareAudioPlayer(
          audioPath: audioUrl, milliSecond: startMs);

      switch (content.value.type) {
        case camera_types.PostStoryContentType.storyImage:
        case camera_types.PostStoryContentType.storyText:
          _playAudioOnly();
          break;
        case camera_types.PostStoryContentType.reel:
        case camera_types.PostStoryContentType.storyVideo:
          videoPlayerController.value?.setVolume(0.0);
          _restartVideoAndAudio();
          break;
      }
    }
  }

  Future<void> _prepareAudioPlayer(
      {required String audioPath, int? milliSecond}) async {
    await audioPlayer.preparePlayer(path: audioPath);
    await audioPlayer.seekTo(milliSecond ?? 0);
    audioPlayer.setFinishMode(finishMode: FinishMode.pause);
  }

  changeBg(bool isTextStory) async {
    if (isTextStory) {
      selectedBgIndex.value = (selectedBgIndex.value + 1) %
          storyGradientColor.length;
    } else {
      final gradient =
          await content.value.content?.getGradientFromImage;
      content.update((val) => val?.bgGradient = gradient);
    }
  }

  changeStoryTime() async {
    currentStoryDurationIndex.value =
        (currentStoryDurationIndex.value + 1) %
            AppRes.storyDurations.length;
    selectStorySecond = AppRes
        .storyDurations[currentStoryDurationIndex.value];
    if (content.value.sound != null) {
      await _pauseAudioOnly();
      _playAudioOnly();
    }
  }
}
