import 'dart:convert';
import 'dart:io';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/duration_extension.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/widget/custom_bg_circle_button.dart';
import 'package:toptap/screen/color_filter_screen/color_filter_screen.dart';
import 'package:toptap/screen/create_feed_screen/create_feed_screen_controller.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';
import 'package:video_player/video_player.dart';

class FeedVideoView extends StatelessWidget {
  final CreateFeedScreenController controller;

  const FeedVideoView(
      {super.key, required this.controller});

  /// Check if there's an overlay file for this video (only for unprocessed videos)
  Future<String?> _getOverlayPath(String videoPath) async {
    print(
        '🔍 DEBUG: Checking for overlay path for video: $videoPath');

    // CRITICAL FIX: Don't load overlays for already-processed videos
    // If the video was processed by FFmpeg/RetryTech, overlays are already burned into the video
    if (videoPath.contains('processed_video_') ||
        videoPath.contains('/cache/')) {
      print(
          '🚫 CRITICAL: Skipping overlay loading for processed video: $videoPath');
      print(
          '   This video already has overlays burned into the frames.');
      return null;
    }

    try {
      // CRITICAL FIX: FFmpeg service creates files with '_overlay_metadata.json' suffix
      final overlayInfoPath = videoPath.replaceAll(
          '.mp4', '_overlay_metadata.json');
      final overlayInfoFile = File(overlayInfoPath);
      print(
          '🔍 DEBUG: Looking for overlay info file: $overlayInfoPath');
      print(
          '🔍 DEBUG: Overlay info file exists: ${await overlayInfoFile.exists()}');

      if (await overlayInfoFile.exists()) {
        final overlayInfoContent =
            await overlayInfoFile.readAsString();
        print(
            '🔍 DEBUG: Overlay info content: $overlayInfoContent');
        final overlayInfo = json.decode(overlayInfoContent);

        // CRITICAL DEBUG: Log the processing method to understand why overlays might be skipped
        final processingMethod =
            overlayInfo['processingMethod'];
        print(
            '🔍 DEBUG: Processing method in metadata: $processingMethod');
        print(
            '🔍 DEBUG: hasOverlay value: ${overlayInfo['hasOverlay']}');

        // CRITICAL FIX: Check if this is metadata for a processed video
        if (overlayInfo['processingMethod'] ==
                'retrytech_plugin_overlay' ||
            overlayInfo['processingMethod'] ==
                'video_compress_with_overlay' ||
            overlayInfo['processingMethod'] ==
                'ffmpeg_integrated_overlays' ||
            overlayInfo['overlaysIntegrated'] == true) {
          print(
              '🚫 CRITICAL: Skipping overlay - this is a processed video with burned-in overlays');
          print(
              '🚫 Processing method was: $processingMethod');
          print(
              '🚫 Overlays integrated: ${overlayInfo['overlaysIntegrated']}');
          return null;
        }

        print(
            '✅ Processing method check passed - proceeding with overlay loading');

        if (overlayInfo['hasOverlay'] == true &&
            overlayInfo['overlayPath'] != null) {
          final overlayPath =
              overlayInfo['overlayPath'] as String;
          final overlayFile = File(overlayPath);
          print(
              '🔍 DEBUG: Checking overlay file: $overlayPath');

          final overlayExists = await overlayFile.exists();
          print(
              '🔍 DEBUG: Overlay file exists: $overlayExists');

          if (overlayExists) {
            final overlaySize = await overlayFile.length();
            print(
                '🔍 DEBUG: Overlay file size: $overlaySize bytes');
            print(
                '✅ Found overlay file for unprocessed video: $overlayPath');
            return overlayPath;
          } else {
            print(
                '❌ Overlay file not found at: $overlayPath');
            print('❌ This might be because:');
            print(
                '   1. File was saved to temporary directory and cleaned up');
            print('   2. Path is incorrect');
            print('   3. File permissions issue');
          }
        } else {
          print('❌ No overlay info or hasOverlay is false');
          print(
              '❌ hasOverlay: ${overlayInfo['hasOverlay']}');
          print(
              '❌ overlayPath: ${overlayInfo['overlayPath']}');
        }
      } else {
        print(
            '📝 No overlay info file found (normal for unprocessed videos)');
      }
    } catch (e) {
      print('⚠️ Error checking for overlay: $e');
    }

    print(
        '📝 No separate overlay needed for video: $videoPath');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        ImageWithFilter? video = controller.video.value;

        if (video == null) {
          print(
              '🔍 DEBUG: No video to display in FeedVideoView');
          return const SizedBox();
        }

        VideoPlayerController? playerController =
            controller.videoPlayerController.value;

        if (playerController == null) {
          print(
              '🔍 DEBUG: No video player controller in FeedVideoView');
          return const SizedBox();
        }

        print(
            '🔍 DEBUG: FeedVideoView displaying video: ${video.media.path}');
        print(
            '🔍 DEBUG: Video file exists: ${File(video.media.path).existsSync()}');

        double width = playerController.value.size.width;
        double height = playerController.value.size.height;

        print(
            '🔍 DEBUG: Video dimensions: ${width}x${height}');

        return Container(
          width: Get.width,
          height: Get.height *
              0.4, // Increased to 40% for better visibility
          margin: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: blackPure(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base video layer
                ColorFiltered(
                  colorFilter:
                      ColorFilter.matrix(video.colorFilter),
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit
                          .cover, // CRITICAL FIX: Use cover to match editing coordinate system
                      child: SizedBox(
                        width: width,
                        height: height,
                        child:
                            VideoPlayer(playerController),
                      ),
                    ),
                  ),
                ),

                // CRITICAL FIX: Display live overlays from editing controller
                _buildVideoEditingOverlays(),

                // Overlay layer for edits (if available and no live overlays)
                // Only use FutureBuilder overlay if we don't have live editing overlays
                if (controller.videoEditingController
                        ?.hasVideoEdits !=
                    true)
                  FutureBuilder<String?>(
                    future:
                        _getOverlayPath(video.media.path),
                    builder: (context, snapshot) {
                      print(
                          '🔍 DEBUG: FutureBuilder overlay state (fallback):');
                      print(
                          '   hasData: ${snapshot.hasData}');
                      print('   data: ${snapshot.data}');
                      print(
                          '   hasError: ${snapshot.hasError}');
                      print('   error: ${snapshot.error}');

                      if (snapshot.hasData &&
                          snapshot.data != null) {
                        print(
                            '📋 Displaying fallback video overlay: ${snapshot.data}');
                        return Positioned.fill(
                          child: Image.file(
                            File(snapshot.data!),
                            fit: BoxFit
                                .cover, // FIXED: Use cover to match video display
                            errorBuilder: (context, error,
                                stackTrace) {
                              print(
                                  '❌ Error loading overlay image: $error');
                              return const SizedBox();
                            },
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        print(
                            '❌ FutureBuilder error: ${snapshot.error}');
                      }

                      return const SizedBox();
                    },
                  ),

                // Video controls overlay
                ValueListenableBuilder(
                  valueListenable: playerController,
                  builder: (context, value, child) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 10),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                CustomBgCircleButton(
                                  image: AssetRes.icFilter,
                                  onTap: () {
                                    if (controller
                                            .videoPlayerController
                                            .value !=
                                        null) {
                                      playerController
                                          .pause();
                                      Get.bottomSheet(
                                              ColorFilterScreen(
                                                images: [
                                                  video
                                                ],
                                                onChanged:
                                                    (items) {
                                                  controller
                                                      .video
                                                      .value = items.first;
                                                },
                                                mediaType:
                                                    MediaType
                                                        .video,
                                                videoPlayerController:
                                                    controller
                                                        .videoPlayerController
                                                        .value,
                                              ),
                                              isScrollControlled:
                                                  true,
                                              ignoreSafeArea:
                                                  false)
                                          .then((value) {
                                        playerController
                                            .play();
                                      });
                                    } else {
                                      Loggers.error(
                                          'Video Player controller not found');
                                    }
                                  },
                                ),
                                const SizedBox(width: 10),
                                CustomBgCircleButton(
                                  image: AssetRes.icDelete,
                                  onTap: controller
                                      .selectedVideoDelete,
                                ),
                              ],
                            ),
                          ),
                          CustomBgCircleButton(
                              image: value.isPlaying
                                  ? AssetRes.icPause
                                  : AssetRes.icPlay,
                              bgColor: textDarkGrey(context)
                                  .withValues(alpha: .4),
                              size: const Size(65, 65),
                              iconSize: 40,
                              onTap: () {
                                if (value.isPlaying) {
                                  playerController.pause();
                                } else {
                                  playerController.play();
                                }
                              }),
                          Container(
                            height: 35,
                            width: double.infinity,
                            margin:
                                const EdgeInsets.symmetric(
                                    horizontal: 15),
                            decoration: ShapeDecoration(
                                color: textDarkGrey(context)
                                    .withValues(alpha: .3),
                                shape: SmoothRectangleBorder(
                                    borderRadius:
                                        SmoothBorderRadius(
                                            cornerRadius: 5,
                                            cornerSmoothing:
                                                1))),
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                    width: 40,
                                    child: Text(
                                      value.position
                                          .printDuration,
                                      style: TextStyleCustom
                                          .outFitMedium500(
                                              color: whitePure(
                                                  context),
                                              fontSize: 12),
                                    )),
                                Expanded(
                                  child: Slider(
                                    value: value.position
                                        .inMicroseconds
                                        .toDouble(),
                                    min: 0,
                                    max: value.duration
                                        .inMicroseconds
                                        .toDouble(),
                                    thumbColor:
                                        themeAccentSolid(
                                            context),
                                    activeColor:
                                        whitePure(context),
                                    inactiveColor:
                                        whitePure(context)
                                            .withValues(
                                                alpha: .3),
                                    onChangeStart: (value) {
                                      playerController
                                          .pause();
                                    },
                                    onChangeEnd: (value) {
                                      playerController
                                          .play();
                                    },
                                    onChanged: (value) {
                                      playerController
                                          .seekTo(Duration(
                                              microseconds:
                                                  value
                                                      .toInt()));
                                    },
                                  ),
                                ),
                                Container(
                                  width: 40,
                                  alignment:
                                      AlignmentDirectional
                                          .centerEnd,
                                  child: Text(
                                    value.duration
                                        .printDuration,
                                    style: TextStyleCustom
                                        .outFitMedium500(
                                            color: whitePure(
                                                context),
                                            fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build video editing overlays from editing controller
  Widget _buildVideoEditingOverlays() {
    // Check if we have an editing controller with video edits
    final editingController =
        controller.videoEditingController;

    print('🔍 DEBUG: _buildVideoEditingOverlays called');
    print(
        '🔍 DEBUG: videoEditingController = $editingController');

    if (editingController == null) {
      print(
          '🔍 DEBUG: No editing controller available for overlays');
      return const SizedBox.shrink();
    }

    // Check if editing controller has video edits
    try {
      // Try to access the properties of the editing controller
      final hasVideoEdits =
          editingController.hasVideoEdits ?? false;
      final videoTextElements =
          editingController.videoTextElements ?? [];
      final videoStickerElements =
          editingController.videoStickerElements ?? [];
      final videoDrawingPaths =
          editingController.videoDrawingPaths ?? [];

      print('🔍 DEBUG: hasVideoEdits = $hasVideoEdits');
      print(
          '🔍 DEBUG: videoTextElements length = ${videoTextElements.length}');
      print(
          '🔍 DEBUG: videoStickerElements length = ${videoStickerElements.length}');
      print(
          '🔍 DEBUG: videoDrawingPaths length = ${videoDrawingPaths.length}');

      if (!hasVideoEdits) {
        print(
            '🔍 DEBUG: No video edits available for overlays');
        return const SizedBox.shrink();
      }

      print(
          '🎨 CRITICAL: Displaying video overlays in CreateFeedScreen');
      print(
          '  - Text elements: ${videoTextElements.length}');
      print(
          '  - Sticker elements: ${videoStickerElements.length}');
      print(
          '  - Drawing paths: ${videoDrawingPaths.length}');

      // Get feed container dimensions for coordinate conversion
      final feedContainerWidth =
          Get.width - 32; // Account for margins
      final feedContainerHeight = Get.height * 0.4;

      // Calculate scale factors for coordinate conversion (use for all elements)
      final editingScreenWidth = Get.width;
      final editingScreenHeight = Get.height;
      final scaleX =
          feedContainerWidth / editingScreenWidth;
      final scaleY =
          feedContainerHeight / editingScreenHeight;

      print('📐 FEED CONTAINER DIMENSIONS:');
      print('   - Width: $feedContainerWidth');
      print('   - Height: $feedContainerHeight');
      print('   - Scale factors: X=$scaleX, Y=$scaleY');

      return Positioned.fill(
        child: Stack(
          children: [
            // Text elements overlay
            if (videoTextElements.isNotEmpty)
              ...videoTextElements
                  .map<Widget>((textElement) {
                // CRITICAL FIX: Convert coordinates from editing screen to feed screen
                final originalPosition =
                    textElement.position;

                // Convert position with proper scaling
                final convertedPosition = Offset(
                  originalPosition.dx * scaleX,
                  originalPosition.dy * scaleY,
                );

                print(
                    '📝 FEED TEXT COORDINATE CONVERSION:');
                print(
                    '   - Original: (${originalPosition.dx}, ${originalPosition.dy})');
                print(
                    '   - Scale factors: X=$scaleX, Y=$scaleY');
                print(
                    '   - Converted: (${convertedPosition.dx}, ${convertedPosition.dy})');
                print('   - Text: "${textElement.text}"');

                return Positioned(
                  left: convertedPosition.dx,
                  top: convertedPosition.dy,
                  child: Transform.scale(
                    scale: (textElement.scale ?? 1.0) *
                        scaleX, // Scale the text size too
                    child: Transform.rotate(
                      angle: textElement.rotation ?? 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              Colors.black.withOpacity(0.7),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.3),
                              width: 1),
                        ),
                        child: Text(
                          textElement.text ?? '',
                          style: TextStyle(
                            color: textElement.color ??
                                Colors.white,
                            fontSize: (textElement
                                        .fontSize ??
                                    16.0) *
                                scaleX, // Scale font size
                            fontWeight:
                                textElement.fontWeight ??
                                    FontWeight.normal,
                            fontFamily:
                                textElement.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),

            // Sticker elements overlay
            if (videoStickerElements.isNotEmpty)
              ...videoStickerElements
                  .map<Widget>((stickerElement) {
                // CRITICAL FIX: Convert coordinates from editing screen to feed screen
                final originalPosition =
                    stickerElement.position;

                final convertedPosition = Offset(
                  originalPosition.dx * scaleX,
                  originalPosition.dy * scaleY,
                );

                print(
                    '🎭 FEED STICKER COORDINATE CONVERSION:');
                print(
                    '   - Original: (${originalPosition.dx}, ${originalPosition.dy})');
                print(
                    '   - Converted: (${convertedPosition.dx}, ${convertedPosition.dy})');
                print(
                    '   - Asset: "${stickerElement.assetPath}"');

                return Positioned(
                  left: convertedPosition.dx,
                  top: convertedPosition.dy,
                  child: Transform.scale(
                    scale: (stickerElement.scale ?? 1.0) *
                        scaleX, // Scale the sticker size
                    child: Transform.rotate(
                      angle: stickerElement.rotation ?? 0.0,
                      child: Image.asset(
                        stickerElement.assetPath ?? '',
                        width:
                            (stickerElement.size?.width ??
                                    50) *
                                scaleX, // Scale width
                        height:
                            (stickerElement.size?.height ??
                                    50) *
                                scaleY, // Scale height
                        fit: BoxFit.contain,
                        errorBuilder:
                            (context, error, stackTrace) {
                          print(
                              '❌ Error loading sticker: $error');
                          return Container(
                            width: (stickerElement
                                        .size?.width ??
                                    50) *
                                scaleX,
                            height: (stickerElement
                                        .size?.height ??
                                    50) *
                                scaleY,
                            color: Colors.grey
                                .withOpacity(0.3),
                            child: const Icon(
                                Icons.broken_image,
                                color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }).toList(),

            // Drawing paths overlay
            if (videoDrawingPaths.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _DrawingOverlayPainter(
                    paths: videoDrawingPaths,
                    scaleX:
                        scaleX, // Pass scale factors for coordinate conversion
                    scaleY: scaleY,
                  ),
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error building video editing overlays: $e');
      return const SizedBox.shrink();
    }
  }
}

/// Custom painter for drawing paths overlay in CreateFeedScreen
class _DrawingOverlayPainter extends CustomPainter {
  final List paths;
  final double scaleX;
  final double scaleY;

  _DrawingOverlayPainter({
    required this.paths,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('🎨 DRAWING OVERLAY PAINTER:');
    print('   - Canvas size: ${size.width}x${size.height}');
    print('   - Scale factors: X=$scaleX, Y=$scaleY');
    print('   - Paths to draw: ${paths.length}');

    for (final drawingPath in paths) {
      if (drawingPath.points == null ||
          drawingPath.points.isEmpty) continue;

      final paint = Paint()
        ..color = drawingPath.color ?? Colors.white
        ..strokeWidth = (drawingPath.strokeWidth ?? 3.0) *
            scaleX // Scale stroke width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      bool first = true;

      for (final point in drawingPath.points) {
        // CRITICAL FIX: Convert coordinates from editing screen to feed screen
        final convertedX = point.dx * scaleX;
        final convertedY = point.dy * scaleY;

        if (first) {
          path.moveTo(convertedX, convertedY);
          first = false;
          print(
              '   - Path start: (${point.dx}, ${point.dy}) → ($convertedX, $convertedY)');
        } else {
          path.lineTo(convertedX, convertedY);
        }
      }

      canvas.drawPath(path, paint);
      print(
          '   - Drew path with ${drawingPath.points.length} points, color: ${drawingPath.color}');
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      true;
}
