import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/duration_extension.dart';
import 'package:toptap/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:toptap/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class ReelSeekBar extends StatefulWidget {
  final CachedVideoPlayerPlusController? videoController;
  final ReelController controller;

  const ReelSeekBar(
      {super.key,
      required this.videoController,
      required this.controller});

  @override
  State<ReelSeekBar> createState() => _ReelSeekBarState();
}

class _ReelSeekBarState extends State<ReelSeekBar> {
  late final GlobalKey sliderKey = GlobalKey();
  late final CachedVideoPlayerPlusController?
      _mainController = widget.videoController;
  CachedVideoPlayerPlusController? _overlayController;

  OverlayEntry? _overlayEntry;
  Offset? _dragPosition;
  Duration _currentPosition = Duration.zero;
  bool _isOverlayInitialized = false;
  final dashboardController =
      Get.find<DashboardScreenController>();

  @override
  void initState() {
    super.initState();
    // 🔒 Only add listener if controller is valid
    try {
      if (_mainController != null) {
        final _ =
            _mainController!.value; // Check if disposed
        _mainController!.addListener(_updateMainPosition);
      }
    } catch (e) {
      if (!e.toString().contains('disposed')) rethrow;
    }
  }

  void _updateMainPosition() async {
    // 🔒 Check if still mounted and controller is valid
    if (!mounted) return;

    try {
      final pos = await _mainController?.position;
      if (pos != null && mounted) {
        setState(() => _currentPosition = pos);
      }
    } catch (e) {
      if (!e.toString().contains('disposed')) rethrow;
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;

    if (_isOverlayInitialized &&
        _overlayController != null) {
      _overlayController!
          .removeListener(_updateOverlayPosition);
      _overlayController!.dispose();
      _overlayController = null;
      _isOverlayInitialized = false;
    }

    _dragPosition = null;
  }

  void _updateOverlayPosition() async {
    final pos = await _overlayController?.position;
    if (pos != null && mounted) {
      setState(() => _currentPosition = pos);
    }
  }

  void _updateOverlayLocation(Offset globalOffset) {
    _dragPosition = globalOffset;
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _createOverlay() async {
    _removeOverlay();

    final url = _mainController?.dataSource;
    if (url == null) return;
    final newController =
        CachedVideoPlayerPlusController.networkUrl(
            Uri.parse(url));
    await newController.initialize();
    newController.addListener(_updateOverlayPosition);

    _overlayController = newController;
    _isOverlayInitialized = true;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        if (_dragPosition == null ||
            !_isOverlayInitialized) {
          return const SizedBox();
        }

        final screenWidth =
            MediaQuery.of(context).size.width;
        final double dx = (_dragPosition!.dx - 30)
            .clamp(0, screenWidth - 100);
        bool isPostUploading = dashboardController
                .postProgress.value.uploadType !=
            UploadType.none;
        final top =
            MediaQuery.of(context).size.height * 0.75 -
                (!isPostUploading ? 60 : 80);

        return Positioned(
          left: dx,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  width: 100,
                  height: 170,
                  child: ClipRRect(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 10,
                          cornerSmoothing: 1),
                      child: CachedVideoPlayerPlus(
                          _overlayController!)),
                ),
                Container(
                  width: 100,
                  height: 170,
                  decoration: ShapeDecoration(
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 10,
                          cornerSmoothing: 1),
                      side: BorderSide(
                        color: whitePure(context)
                            .withAlpha(50),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _currentPosition.printDuration,
                    style: TextStyleCustom.outFitMedium500(
                      color: whitePure(context),
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    WidgetsBinding.instance
        .addPostFrameCallback((timeStamp) {
      Overlay.of(context).insert(_overlayEntry!);
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _mainController?.removeListener(_updateMainPosition);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _isOverlayInitialized
        ? _overlayController
        : _mainController;

    if (controller == null)
      return const SizedBox(height: 15);

    // 🔒 CRITICAL: Check if controller is disposed before using ValueListenableBuilder
    try {
      final _ =
          controller.value; // This will throw if disposed
    } catch (e) {
      if (e.toString().contains('disposed')) {
        return const SizedBox(height: 15);
      }
      rethrow;
    }

    return ValueListenableBuilder<
        CachedVideoPlayerPlusValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration =
            value.duration.inMicroseconds.toDouble();
        final position =
            value.position.inMicroseconds.toDouble();

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            padding: EdgeInsets.zero,
            overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 0),
            thumbShape: _InvisibleThumbShape(),
            trackShape: const RectangularSliderTrackShape(),
          ),
          child: Listener(
            onPointerMove: (event) =>
                _updateOverlayLocation(event.position),
            child: Slider(
              key: sliderKey,
              value: position.clamp(0, duration),
              min: 0,
              max: duration,
              activeColor: textLightGrey(context),
              inactiveColor: textDarkGrey(context),
              onChangeStart: (value) {
                if (duration <= 0) {
                  return;
                }
                _createOverlay();
                // 🔒 Check if disposed before pause
                try {
                  _mainController?.pause();
                } catch (e) {
                  if (!e.toString().contains('disposed'))
                    rethrow;
                }
              },
              onChangeEnd: (value) {
                if (duration <= 0) {
                  return;
                }
                _removeOverlay();
                // 🔒 Check if disposed before play/seek
                try {
                  _mainController?.play();
                  _mainController?.seekTo(Duration(
                      microseconds: value.toInt()));
                } catch (e) {
                  if (!e.toString().contains('disposed'))
                    rethrow;
                }
              },
              onChanged: (value) {
                if (duration <= 0) {
                  return;
                }
                // 🔒 Check if disposed before seek
                try {
                  _overlayController?.seekTo(Duration(
                      microseconds: value.toInt()));
                } catch (e) {
                  if (!e.toString().contains('disposed'))
                    rethrow;
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _InvisibleThumbShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(15, 15);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter? labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    // No thumb to paint
  }

  bool hitTest(
    Offset thumbCenter,
    Offset touchPosition, {
    required Size sizeWithOverflow,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
  }) {
    // Expand interactive area (e.g., 24x24)
    return (touchPosition - thumbCenter).distance <= 12;
  }
}
