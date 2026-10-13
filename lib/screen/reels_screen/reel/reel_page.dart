import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/service/settings_service.dart';
import 'package:shortzz/common/widget/black_gradient_shadow.dart';
import 'package:shortzz/common/widget/double_tap_detector.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/model/post_story/post_by_id.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reel/widget/reel_animation_like.dart';
import 'package:shortzz/screen/reels_screen/reel/widget/reel_seek_bar.dart';
import 'package:shortzz/screen/reels_screen/reel/widget/side_bar_list.dart';
import 'package:shortzz/screen/reels_screen/reel/widget/user_information.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ReelPage extends StatelessWidget {
  final Post reelData;
  final CachedVideoPlayerPlusController?
      videoPlayerController;
  final GlobalKey likeKey;
  final PostByIdData? postByIdData;

  const ReelPage(
      {super.key,
      required this.reelData,
      this.videoPlayerController,
      required this.likeKey,
      this.postByIdData});

  /// 🔒 Helper to check if a controller is valid (not disposed)
  bool _isControllerValid(
      CachedVideoPlayerPlusController? controller) {
    if (controller == null) return false;
    try {
      final _ = controller.value; // Throws if disposed
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get settings service for user preferences
    final SettingsService settings =
        SettingsService.instance;

    ReelController controller;
    if (Get.isRegistered<ReelController>(
        tag: '${reelData.id}')) {
      controller =
          Get.find<ReelController>(tag: '${reelData.id}');
      // Delay update until after current frame to ensure proper UI update without conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.updateReelData(reel: reelData);
        controller.notifyCommentSheet(postByIdData);
      });
    } else {
      controller = Get.put(ReelController(reelData.obs),
          tag: '${reelData.id}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.notifyCommentSheet(postByIdData);
      });
    }

    Widget _buildVideoContent() {
      // 🔒 CRITICAL: Check if controller exists and is not disposed
      if (videoPlayerController == null) {
        return const LoaderWidget();
      }

      try {
        // 🔒 This will throw if controller is disposed
        final value = videoPlayerController!.value;

        // 🔒 Additional check: must be initialized
        if (!value.isInitialized) {
          return const LoaderWidget();
        }

        final size = value.size;

        // 🔒 Use _SafeVideoPlayer widget to properly handle disposed controllers
        return _SafeVideoPlayer(
          controller: videoPlayerController!,
          size: size,
        );
      } catch (e) {
        // Controller is disposed or not initialized
        if (e.toString().contains('disposed')) {
          print(
              '⚠️ Controller disposed in _buildVideoContent, showing loader');
        }
        return const LoaderWidget();
      }
    }

    Widget _buildPlayPauseOverlay(
        CachedVideoPlayerPlusController? controller) {
      // 🔒 CRITICAL FIX: Check if controller is disposed before using ValueListenableBuilder
      if (controller == null) {
        return const SizedBox.shrink();
      }

      try {
        // 🔒 This will throw if controller is disposed
        final _ = controller.value;
      } catch (e) {
        // Controller is disposed, return empty widget
        if (e.toString().contains('disposed')) {
          print(
              '⚠️ Controller disposed in _buildPlayPauseOverlay, returning empty widget');
          return const SizedBox.shrink();
        }
        rethrow;
      }

      return ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, value, child) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 10),
            opacity: value.isPlaying ? 0.0 : 1.0,
            child: Align(
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: 30,
                  cornerSmoothing: 1,
                ),
                child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                        color: blackPure(context)
                            .withValues(alpha: 0.5),
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Image.asset(
                        value.isPlaying
                            ? AssetRes.icPause
                            : AssetRes.icPlay,
                        width: 35,
                        height: 35,
                        color: bgGrey(context))),
              ),
            ),
          );
        },
      );
    }

    void _togglePlayPause() {
      if (videoPlayerController == null) {
        return;
      }

      try {
        // 🔒 CRITICAL: Check if disposed before operations
        final controllerValue =
            videoPlayerController!.value;

        if (controllerValue.isPlaying) {
          videoPlayerController!.pause();
        } else {
          videoPlayerController!.play();
        }
      } catch (e) {
        if (e.toString().contains('disposed')) {
          print(
              '⚠️ Controller disposed in _togglePlayPause, ignoring tap');
        }
      }
    }

    void _handleVisibilityChanged(VisibilityInfo info) {
      // 🔒 CRITICAL FIX: Check if controller is disposed before ANY operation
      if (videoPlayerController == null) {
        return;
      }

      final visibilityPercent = info.visibleFraction * 100;

      try {
        // 🔒 This will throw if controller is disposed
        final controllerValue =
            videoPlayerController!.value;

        // 🔒 Additional safety: check if initialized
        if (!controllerValue.isInitialized) {
          return;
        }

        // 🔒 Play when mostly visible (>80%), pause when mostly hidden (<20%)
        // Wider gap prevents flickering during scroll
        if (visibilityPercent >= 80) {
          // VisibilityDetector only measures ancestor clipping, not
          // Navigator-stack occlusion — a reel fully covered by a
          // full-screen route (LIVE discovery feed, an actual LIVE
          // stream, create-live) can still report itself as visible here.
          // Respect that overlay's pause instead of fighting it, or its
          // audio leaks into the background. See
          // ReelsScreenController.isPausedForOverlay.
          if (ReelsScreenController.isPausedForOverlay) {
            return;
          }
          // Apply volume and loop settings
          double volume = settings.getReelVolume();
          videoPlayerController!.setVolume(volume);
          videoPlayerController!.setLooping(true);

          // Auto-play if not playing
          if (!controllerValue.isPlaying) {
            videoPlayerController!.play();
            print(
                '🎬 ReelPage playing: visibility $visibilityPercent%');
          }
        } else if (visibilityPercent < 20) {
          // Pause when mostly hidden
          if (controllerValue.isPlaying) {
            videoPlayerController!.pause();
            print(
                '⏸️ ReelPage paused: visibility $visibilityPercent%');
          }
        }
        // Between 20-80%: do nothing to prevent flickering
      } catch (e) {
        // 🔒 Catch disposal errors gracefully
        if (e.toString().contains('disposed')) {
          print(
              '⚠️ Controller already disposed for reel ${reelData.id}, ignoring visibility change');
        } else {
          print('❌ Error in visibility handler: $e');
        }
        return;
      }
    }

    Rx<TapDownDetails?> details = Rx(null);

    return Scaffold(
      backgroundColor: blackPure(context),
      resizeToAvoidBottomInset: false,
      body: VisibilityDetector(
        key: Key('ke1${reelData.video ?? ''}'),
        onVisibilityChanged: _handleVisibilityChanged,
        child: DoubleTapDetector(
          onDoubleTap: (value) {
            if (details.value != null) return;
            details.value = value;
          },
          child: InkWell(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _togglePlayPause();
            },
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                _buildVideoContent(),
                const BlackGradientShadow(),
                // 🔒 Only pass controller to ReelInfoSection if it's valid (not disposed)
                ReelInfoSection(
                    controller: controller,
                    likeKey: likeKey,
                    videoPlayerPlusController:
                        _isControllerValid(
                                videoPlayerController)
                            ? videoPlayerController
                            : null),
                // 🔒 Only show play/pause overlay if controller is valid
                if (_isControllerValid(
                    videoPlayerController))
                  _buildPlayPauseOverlay(
                      videoPlayerController),
                Obx(() {
                  if (details.value == null) {
                    return const SizedBox();
                  }
                  return ReelAnimationLike(
                    likeKey: likeKey,
                    position: details.value!.globalPosition,
                    size: const Size(50, 50),
                    leftRightPosition: 8,
                    onLikeCall: () {
                      if (controller
                              .reelData.value.isLiked ==
                          true) return;
                      controller.onLikeTap();
                    },
                    onCompleteAnimation: () {
                      details.value = null;
                    },
                  );
                })
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReelInfoSection extends StatelessWidget {
  final ReelController controller;
  final GlobalKey likeKey;
  final CachedVideoPlayerPlusController?
      videoPlayerPlusController;

  const ReelInfoSection(
      {super.key,
      required this.controller,
      required this.likeKey,
      required this.videoPlayerPlusController});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ReelInfoRow(
            controller: controller, likeKey: likeKey),
        ReelSeekBar(
            videoController: videoPlayerPlusController,
            controller: controller),
      ],
    );
  }
}

class ReelInfoRow extends StatelessWidget {
  final ReelController controller;
  final GlobalKey likeKey;

  const ReelInfoRow(
      {super.key,
      required this.controller,
      required this.likeKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
            child: UserInformation(controller: controller)),
        SideBarList(
            controller: controller, likeKey: likeKey),
      ],
    );
  }
}

/// 🔒 Safe video player widget that properly handles disposed controllers
/// This widget catches errors during build and shows a loader instead of crashing
class _SafeVideoPlayer extends StatefulWidget {
  final CachedVideoPlayerPlusController controller;
  final Size size;

  const _SafeVideoPlayer({
    required this.controller,
    required this.size,
  });

  @override
  State<_SafeVideoPlayer> createState() =>
      _SafeVideoPlayerState();
}

class _SafeVideoPlayerState
    extends State<_SafeVideoPlayer> {
  bool _hasError = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Check if controller is still valid
    _checkController();
    // Listen for disposal
    _addListener();
  }

  void _addListener() {
    try {
      widget.controller.addListener(_onControllerUpdate);
    } catch (e) {
      // Controller already disposed
      _hasError = true;
    }
  }

  void _onControllerUpdate() {
    // If we get an update, controller is still valid
    if (mounted && !_isDisposed) {
      try {
        final _ = widget.controller.value;
      } catch (e) {
        // Controller disposed
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      widget.controller.removeListener(_onControllerUpdate);
    } catch (e) {
      // Controller already disposed, ignore
    }
    super.dispose();
  }

  void _checkController() {
    try {
      // This will throw if disposed
      final value = widget.controller.value;
      if (!value.isInitialized) {
        _hasError = true;
      }
    } catch (e) {
      _hasError = true;
    }
  }

  @override
  void didUpdateWidget(_SafeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      // Controller changed, recheck
      _hasError = false;
      _checkController();
      // Update listener
      try {
        oldWidget.controller
            .removeListener(_onControllerUpdate);
      } catch (e) {
        // Old controller disposed
      }
      _addListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const LoaderWidget();
    }

    // Final safety check before building
    try {
      final value = widget.controller.value;
      if (!value.isInitialized) {
        return const LoaderWidget();
      }
    } catch (e) {
      // Controller disposed - show loader
      return const LoaderWidget();
    }

    // Wrap CachedVideoPlayerPlus in an error handler
    return _VideoErrorBoundary(
      child: ClipRRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: (widget.size.width) < (widget.size.height)
                ? BoxFit.cover
                : BoxFit.fitWidth,
            child: SizedBox(
              width: widget.size.width,
              height: widget.size.height,
              child:
                  CachedVideoPlayerPlus(widget.controller),
            ),
          ),
        ),
      ),
      onError: () {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      },
    );
  }
}

/// Error boundary widget that catches errors in child widget tree
class _VideoErrorBoundary extends StatefulWidget {
  final Widget child;
  final VoidCallback? onError;

  const _VideoErrorBoundary({
    required this.child,
    this.onError,
  });

  @override
  State<_VideoErrorBoundary> createState() =>
      _VideoErrorBoundaryState();
}

class _VideoErrorBoundaryState
    extends State<_VideoErrorBoundary> {
  bool _hasError = false;
  FlutterExceptionHandler? _previousErrorHandler;

  @override
  void initState() {
    super.initState();
    // Save previous error handler
    _previousErrorHandler = FlutterError.onError;
    // Set up error handler that chains to previous
    FlutterError.onError = _handleFlutterError;
  }

  @override
  void dispose() {
    // Restore previous error handler
    FlutterError.onError = _previousErrorHandler;
    super.dispose();
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    final error = details.exception.toString();
    // Only handle video player related errors
    if (error.contains('disposed') ||
        error.contains('playerId') ||
        error.contains('CachedVideoPlayerPlus')) {
      print(
          '⚠️ _VideoErrorBoundary caught video error: $error');
      if (mounted && !_hasError) {
        setState(() {
          _hasError = true;
        });
        widget.onError?.call();
      }
      // Don't propagate this error
      return;
    }

    // Chain to previous handler for non-video errors
    _previousErrorHandler?.call(details);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const LoaderWidget();
    }
    return widget.child;
  }
}
