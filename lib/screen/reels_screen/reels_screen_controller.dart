import 'dart:async';
import 'dart:io';

import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/video_memory_manager.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/model/post_story/comment/fetch_comment_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/comment_sheet/helper/comment_helper.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/home_screen/home_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/screen/report_sheet/report_sheet.dart';
import 'package:shortzz/utilities/app_res.dart';

class ReelsScreenController extends BaseController {
  static const tag = 'REEL';
  RxBool isVideoDisposing = false.obs;

  DashboardScreenController dashboardController =
      Get.find<DashboardScreenController>();

  HomeScreenController homeScreenController =
      Get.find<HomeScreenController>();
  final RxDouble previousPosition = 0.0.obs;

  // Use VideoMemoryManager for better memory management
  VideoMemoryManager get _videoMemoryManager =>
      VideoMemoryManager.instance;

  RxMap<int, CachedVideoPlayerPlusController>
      videoControllers =
      <int, CachedVideoPlayerPlusController>{}.obs;

  RxList<Post> reels = <Post>[].obs;
  RxInt position = 0.obs;
  Rx<TabType> selectedReelCategory =
      TabType.values.first.obs;
  PageController pageController = PageController();
  CommentHelper commentHelper = CommentHelper();
  Future<void> Function()? onFetchMoreData;
  Future<void> Function()? onRefresh;
  bool isHomePage;

  // 🔒 Track pending initializations to prevent duplicate work
  final Set<int> _pendingInitializations = {};

  // 🔒 Track if we're currently scrolling to prevent aggressive cleanup
  bool _isScrolling = false;

  ReelsScreenController(
      {required this.reels,
      required this.position,
      required this.onFetchMoreData,
      this.onRefresh,
      required this.isHomePage});

  @override
  void onInit() {
    super.onInit();
    pageController =
        PageController(initialPage: position.value);

    // 🔒 Add scroll listener to track scroll state
    pageController.addListener(_onScrollUpdate);

    if (isHomePage) {
      _setupDashboardController();
    }
    if (!isHomePage) {
      initVideoPlayer();
    }
  }

  // 🔒 Track scroll state to prevent aggressive cleanup during scrolling
  void _onScrollUpdate() {
    if (pageController.position.isScrollingNotifier.value) {
      _isScrolling = true;
    } else {
      // Delay resetting scroll state to allow settling
      Future.delayed(const Duration(milliseconds: 300), () {
        _isScrolling = false;
      });
    }
  }

  @override
  void onClose() {
    super.onClose();
    // 🔒 Remove scroll listener before disposing
    pageController.removeListener(_onScrollUpdate);
    // Dispose PageController to prevent memory leak
    pageController.dispose();
    // 🔒 Clear pending initializations
    _pendingInitializations.clear();
    disposeAllController();
  }

  void _setupDashboardController() {
    dashboardController.onBottomIndexChanged = (index) {
      if (index == 0) {
        videoControllers[position.value]?.play();
      } else {
        videoControllers[position.value]?.pause();
      }
    };
  }

  /// Pause the currently visible reel when a full-screen overlay (going LIVE, a
  /// call, etc.) is pushed over the feed. The bottom-tab index does not change
  /// in that case, so the feed would otherwise keep playing audio in the
  /// background. See [resumeForOverlay].
  void pauseForOverlay() {
    try {
      videoControllers[position.value]?.pause();
    } catch (_) {}
  }

  /// Resume the current reel after such an overlay is dismissed, but only while
  /// the feed tab is the one on screen.
  void resumeForOverlay() {
    try {
      if (dashboardController.selectedPageIndex.value == 0) {
        videoControllers[position.value]?.play();
      }
    } catch (_) {}
  }

  /// Pauses the home-feed reels if that controller is currently alive. Safe to
  /// call from anywhere (e.g. before opening the LIVE screen).
  static void pauseHomeFeed() {
    if (Get.isRegistered<ReelsScreenController>(tag: tag)) {
      Get.find<ReelsScreenController>(tag: tag).pauseForOverlay();
    }
  }

  /// Resumes the home-feed reels after an overlay screen is closed.
  static void resumeHomeFeed() {
    if (Get.isRegistered<ReelsScreenController>(tag: tag)) {
      Get.find<ReelsScreenController>(tag: tag).resumeForOverlay();
    }
  }

  Future<void> _fetchMoreData() async {
    // Dynamic threshold: fetch when reaching 80% of list or within 3 items of end
    final fetchThreshold = (reels.length * 0.8)
        .floor()
        .clamp(1, reels.length - 3);

    if (position.value >= fetchThreshold &&
        reels.isNotEmpty) {
      try {
        await onFetchMoreData?.call();

        // After fetching, safely initialize next controller if it exists
        final nextIndex = position.value + 1;
        if (_isValidIndex(nextIndex)) {
          await _initializeControllerAtIndex(nextIndex);
        }
      } catch (e) {
        Loggers.error('Error fetching more data: $e');
      }
    }
  }

  /// Helper method to validate if index is within bounds
  bool _isValidIndex(int index) {
    return index >= 0 &&
        index < reels.length &&
        reels.isNotEmpty;
  }

  void onReportTap() {
    if (!_isValidIndex(position.value)) {
      Loggers.error(
          'Cannot report: invalid position ${position.value}');
      return;
    }

    Get.bottomSheet(
        ReportSheet(
            reportType: ReportType.post,
            id: reels[position.value].id?.toInt()),
        isScrollControlled: true);
  }

  Future<void> initVideoPlayer() async {
    if (reels.isEmpty) {
      Loggers.error(
          'Cannot initialize video player with empty reels list');
      return;
    }

    // Ensure position is valid
    if (!_isValidIndex(position.value)) {
      Loggers.error(
          'Invalid initial position: ${position.value}');
      position.value = 0;
    }

    try {
      /// Initialize and play current video
      await _initializeControllerAtIndex(position.value);
      _playControllerAtIndex(position.value);

      /// Preload previous video if available
      final prevIndex = position.value - 1;
      if (_isValidIndex(prevIndex)) {
        await _initializeControllerAtIndex(prevIndex);
      }

      /// Preload next video if available
      final nextIndex = position.value + 1;
      if (_isValidIndex(nextIndex)) {
        await _initializeControllerAtIndex(nextIndex);
      }
    } catch (e) {
      Loggers.error('Error initializing video player: $e');
    }
  }

  void _playNextReel(int index) {
    if (!_isValidIndex(index)) {
      Loggers.error(
          'Cannot play next reel: invalid index $index');
      return;
    }

    try {
      // Stop previous controller
      final prevIndex = index - 1;
      if (_isValidIndex(prevIndex)) {
        _stopControllerAtIndex(prevIndex);
      }

      // 🔒 Only cleanup far controllers when NOT actively scrolling
      // Increased threshold to 6 positions away to prevent reload during fast scrolling
      if (!_isScrolling) {
        final farBehind = index - 6;
        if (_isValidIndex(farBehind) &&
            videoControllers.containsKey(farBehind)) {
          videoControllers.remove(farBehind);
          Loggers.info(
              '🗑️ Removed controller $farBehind from local tracking (too far behind)');
        }
      }

      // Play current reel
      _playControllerAtIndex(index);

      // 🔒 Preload more videos ahead for smoother scrolling
      for (int i = 1; i <= 2; i++) {
        final nextIndex = index + i;
        if (_isValidIndex(nextIndex)) {
          _initializeControllerAtIndex(nextIndex);
        }
      }
    } catch (e) {
      Loggers.error(
          'Error playing next reel at index $index: $e');
    }
  }

  void _playPreviousReel(int index) {
    if (!_isValidIndex(index)) {
      Loggers.error(
          'Cannot play previous reel: invalid index $index');
      return;
    }

    try {
      // Stop next controller
      final nextIndex = index + 1;
      if (_isValidIndex(nextIndex)) {
        _stopControllerAtIndex(nextIndex);
      }

      // 🔒 Only cleanup far controllers when NOT actively scrolling
      // Increased threshold to 6 positions away to prevent reload during fast scrolling
      if (!_isScrolling) {
        final farAhead = index + 6;
        if (_isValidIndex(farAhead) &&
            videoControllers.containsKey(farAhead)) {
          videoControllers.remove(farAhead);
          Loggers.info(
              '🗑️ Removed controller $farAhead from local tracking (too far ahead)');
        }
      }

      // Play current reel
      _playControllerAtIndex(index);

      // 🔒 Preload more videos behind for smoother scrolling
      for (int i = 1; i <= 2; i++) {
        final prevIndex = index - i;
        if (_isValidIndex(prevIndex)) {
          _initializeControllerAtIndex(prevIndex);
        }
      }
    } catch (e) {
      Loggers.error(
          'Error playing previous reel at index $index: $e');
    }
  }

  RxBool isLoadingVideo = false.obs;

  Future _initializeControllerAtIndex(int index) async {
    // Validate index before proceeding
    if (!_isValidIndex(index)) {
      Loggers.error(
          'Cannot initialize controller: invalid index $index (reels length: ${reels.length})');
      return;
    }

    // 🔒 Prevent duplicate initialization requests
    if (_pendingInitializations.contains(index)) {
      Loggers.info(
          '⏭️ SKIPPING $index - initialization already pending');
      return;
    }

    try {
      // Skip if controller already exists and is initialized in local map
      final existingController = videoControllers[index];
      if (existingController != null) {
        try {
          // 🔒 Check if still valid and initialized
          if (existingController.value.isInitialized) {
            Loggers.info(
                '⏭️ SKIPPING $index - already initialized');
            return;
          }
        } catch (e) {
          // Controller disposed, continue to create new one
          videoControllers.remove(index);
          Loggers.warning(
              '⚠️ Controller $index was disposed, will reinitialize');
        }
      }

      // 🔒 Mark as pending initialization
      _pendingInitializations.add(index);

      final String identifier =
          'reel_${reels[index].id}_$index';

      // Check if controller already exists in memory manager
      CachedVideoPlayerPlusController? controller =
          _videoMemoryManager.getController(identifier);

      if (controller == null) {
        /// Create new controller via memory manager
        final String? videoUrl = reels[index].video;

        if (videoUrl == null || videoUrl.isEmpty) {
          Loggers.error(
              'Video URL is null or empty for reel at index $index');
          _pendingInitializations.remove(index);
          return;
        }

        if (reels.first.id == -1) {
          controller = _videoMemoryManager.createController(
            identifier,
            File(videoUrl),
            isNetworkUrl: false,
          );
        } else {
          controller = _videoMemoryManager.createController(
            identifier,
            videoUrl.addBaseURL(),
            isNetworkUrl: true,
          );
        }

        /// Add to [controllers] list
        videoControllers[index] = controller;
        isLoadingVideo.value = true;

        /// Initialize
        await controller.initialize();
        isLoadingVideo.value = false;

        Loggers.info(
            '🚀🚀🚀 INITIALIZED $index via VideoMemoryManager');
      } else {
        // Reusing existing controller - verify it's still valid
        try {
          final value = controller.value;
          if (!value.isInitialized) {
            await controller.initialize();
          }
          videoControllers[index] = controller;
          _videoMemoryManager
              .markControllerUsed(identifier);
          Loggers.info(
              '♻️ REUSING controller $index from VideoMemoryManager');
        } catch (e) {
          // Controller was disposed in memory manager, recreate
          Loggers.warning(
              '⚠️ Cached controller $index disposed, recreating...');
          _pendingInitializations.remove(index);
          // Recurse to create new controller
          return _initializeControllerAtIndex(index);
        }
      }

      Loggers.info(
          '############################################################');
    } catch (e) {
      isLoadingVideo.value = false;
      Loggers.error(
          'Error initializing controller at index $index: $e');
    } finally {
      // 🔒 Always remove from pending set
      _pendingInitializations.remove(index);
    }
  }

  void _playControllerAtIndex(int index) async {
    // Validate index and home page state
    if (dashboardController.selectedPageIndex.value != 0 &&
        isHomePage) {
      return;
    }

    if (!_isValidIndex(index)) {
      Loggers.error(
          'Cannot play controller: invalid index $index');
      return;
    }

    try {
      CachedVideoPlayerPlusController? controller =
          videoControllers[index];

      if (controller != null) {
        // 🔒 CRITICAL: Check if disposed by accessing .value
        try {
          final value = controller.value;

          if (!value.isInitialized) {
            // Initialize if not ready
            Loggers.warning(
                'Controller $index not initialized, initializing now...');
            await _initializeControllerAtIndex(index);

            final newController = videoControllers[index];
            if (newController != null) {
              // 🔒 Wrap play in try-catch
              try {
                if (newController.value.isInitialized) {
                  newController.play();
                  newController.setLooping(true);
                  Loggers.info(
                      '🚀🚀🚀 PLAYING $index after initialization');
                }
              } catch (e) {
                if (e.toString().contains('disposed')) {
                  Loggers.warning(
                      '⚠️ Controller $index disposed during play attempt');
                  videoControllers.remove(index);
                }
              }
            }
            return;
          }

          // Mark controller as actively used
          final String identifier =
              'reel_${reels[index].id}_$index';
          _videoMemoryManager
              .markControllerUsed(identifier);

          // Check if already playing to avoid redundant calls
          if (value.isPlaying) {
            Loggers.info(
                '⏭️ SKIPPING PLAY $index - already playing');
            return;
          }

          // 🔒 Wrap play in try-catch to handle race condition
          try {
            controller.play();
            controller.setLooping(true);
            videoControllers.refresh();

            DebounceAction.shared.call(() {
              _increaseViewsCount(reels[index]);
            }, milliseconds: 3000);

            Loggers.info('🚀🚀🚀 PLAYING $index');
          } catch (playError) {
            if (playError.toString().contains('disposed')) {
              Loggers.warning(
                  '⚠️ Controller $index disposed during play');
              videoControllers.remove(index);
              // Don't reinitialize here to avoid infinite loop
            } else {
              throw playError;
            }
          }
        } catch (disposalError) {
          // 🔒 Controller was disposed between check and operation
          if (disposalError
              .toString()
              .contains('disposed')) {
            Loggers.warning(
                '⚠️ Controller $index was disposed, reinitializing...');
            videoControllers.remove(index);
            await _initializeControllerAtIndex(index);

            // Try to play after reinitialization - WRAPPED IN TRY-CATCH
            try {
              final reinitController =
                  videoControllers[index];
              if (reinitController != null &&
                  reinitController.value.isInitialized) {
                reinitController.play();
                reinitController.setLooping(true);
                Loggers.info(
                    '🚀🚀🚀 PLAYING $index after reinitialization');
              }
            } catch (e) {
              if (e.toString().contains('disposed')) {
                Loggers.warning(
                    '⚠️ Controller $index disposed after reinit');
                videoControllers.remove(index);
              }
            }
          } else {
            throw disposalError; // Re-throw non-disposal errors
          }
        }
      } else {
        // Controller not in map, initialize it
        Loggers.warning(
            'Controller $index not in map, initializing now...');
        await _initializeControllerAtIndex(index);

        // 🔒 Wrap play in try-catch
        try {
          final initializedController =
              videoControllers[index];
          if (initializedController != null &&
              initializedController.value.isInitialized) {
            initializedController.play();
            initializedController.setLooping(true);
            Loggers.info(
                '🚀🚀🚀 PLAYING $index after initialization');
          } else {
            Loggers.error(
                'Failed to initialize controller at index $index');
          }
        } catch (e) {
          if (e.toString().contains('disposed')) {
            Loggers.warning(
                '⚠️ Controller $index disposed after init');
            videoControllers.remove(index);
          }
        }
      }
    } catch (e) {
      Loggers.error(
          'Error playing controller at index $index: $e');
    }
  }

  void _increaseViewsCount(Post? post) async {
    if (post == null || post.id == null) {
      return Loggers.error('Post not found or ID is null');
    }

    final postId = post.id ?? -1;
    if (postId == -1) {
      return Loggers.error(
          'Post ID $postId not found in reels');
    }

    final reelIndex =
        reels.indexWhere((element) => element.id == postId);
    if (reelIndex == -1) {
      return Loggers.error(
          'Post ID $postId not found in reels');
    }

    final response = await PostService.instance
        .increaseViewsCount(postId: postId);

    if (response.status == true) {
      // Loggers.info('🚀 INCREASE VIEWS COUNT SUCCESSFUL');
      post.increaseViews();
      reels[reelIndex] = post;

      final controllerTag = postId.toString();
      if (Get.isRegistered<ReelController>(
          tag: controllerTag)) {
        Get.find<ReelController>(tag: controllerTag)
            .updateReelData(reel: post);
      }
    }
  }

  void _stopControllerAtIndex(int index) {
    if (!_isValidIndex(index)) {
      return; // Silently ignore invalid indices
    }

    try {
      final controller = videoControllers[index];
      if (controller != null) {
        // 🔒 CRITICAL: Check if disposed before operations
        try {
          final value = controller.value;
          if (value.isInitialized) {
            controller.pause();
            controller
                .seekTo(const Duration()); // Reset position
            Loggers.info('🚀🚀🚀 STOPPED $index');
          }
        } catch (disposalError) {
          if (disposalError
              .toString()
              .contains('disposed')) {
            Loggers.warning(
                '⚠️ Controller $index already disposed, removing from map');
            videoControllers.remove(index);
          } else {
            throw disposalError;
          }
        }
      }
    } catch (e) {
      Loggers.error(
          'Error stopping controller at index $index: $e');
    }
  }

  Future<void> disposeAllController() async {
    Loggers.info(
        '🗑️ Disposing all controllers via VideoMemoryManager');

    // Clear local tracking
    videoControllers.clear();

    // Let VideoMemoryManager handle the actual disposal
    await _videoMemoryManager.disposeAllControllers(
        reason: 'ReelsScreenController disposing');

    Loggers.success(
        '✅ All controllers disposed via VideoMemoryManager');
  }

  void onPageChanged(int index) {
    // Validate new index
    if (!_isValidIndex(index)) {
      Loggers.error(
          'Invalid page index: $index (reels length: ${reels.length})');
      return;
    }

    try {
      commentHelper.detectableTextFocusNode.unfocus();
      commentHelper.detectableTextController.clear();

      if (index > position.value) {
        _fetchMoreData();
        _playNextReel(index);
      } else {
        _playPreviousReel(index);
      }

      position.value = index;
    } catch (e) {
      Loggers.error(
          'Error handling page change to index $index: $e');
    }
  }

  void onUpdateComment(
      Comment comment, bool isReplyComment) {
    final post = reels
        .firstWhereOrNull((e) => e.id == comment.postId);
    if (post == null) {
      return Loggers.error('Post not found');
    }
    final controllerTag = post.id.toString();
    if (Get.isRegistered<ReelController>(
        tag: controllerTag)) {
      Get.find<ReelController>(tag: controllerTag)
          .reelData
          .update((val) => val?.updateCommentCount(1));
    }
  }

  Future<void> onRefreshPage(List<Post> reels) async {
    if (onRefresh == null) {
      return;
    }

    try {
      position.value = 0;

      if (pageController.hasClients) {
        pageController.jumpToPage(position.value);
      }

      // Validate reels list
      if (reels.isEmpty) {
        Loggers.error(
            'Cannot refresh with empty reels list');
        return;
      }

      // Validate video URL
      final videoUrl =
          reels[position.value].video?.addBaseURL();
      if (videoUrl == null || videoUrl.isEmpty) {
        Loggers.error(
            'Cannot refresh: video URL is null or empty');
        return;
      }

      final CachedVideoPlayerPlusController controller =
          CachedVideoPlayerPlusController.networkUrl(
              Uri.parse(videoUrl));
      await controller.initialize();

      // Dispose old controllers
      await disposeAllController();
      videoControllers[position.value] = controller;

      /// Play 1st video
      _playControllerAtIndex(position.value);

      /// Initialize next video if available
      final nextIndex = position.value + 1;
      if (_isValidIndex(nextIndex)) {
        await _initializeControllerAtIndex(nextIndex);
      }
    } catch (e) {
      Loggers.error('Error refreshing reels page: $e');
    }
  }
}
