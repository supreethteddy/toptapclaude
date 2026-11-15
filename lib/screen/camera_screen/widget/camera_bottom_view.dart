import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/widget/custom_border_round_icon.dart';
import 'package:toptap/common/widget/dashed_circle_painter.dart';
import 'package:toptap/model/general/settings_model.dart';
import 'package:toptap/screen/camera_screen/camera_screen_controller.dart';
import 'package:toptap/screen/camera_screen/camera_types.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class CameraBottomView extends StatelessWidget {
  final CameraScreenType cameraType;

  const CameraBottomView({super.key, required this.cameraType});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CameraScreenController>();
    final isReelType = cameraType == CameraScreenType.post;

    return Column(
      children: [
        // Filter/Effect views
        _buildFilterEffectViews(controller),

        // Duration selector (for reels)
        if (isReelType) const _RecordingDurationSelector(),

        // Main control buttons
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              CustomBorderRoundIcon(
                  image: AssetRes.icImage, onTap: controller.onMediaTap),

              // Recording control button
              RecordingControlButton(controller: controller),

              // Stop recording button
              _buildStopRecordingButton(controller),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFilterEffectViews(CameraScreenController controller) {
    return Obx(() {
      if (controller.isUsingDeepAr &&
          controller.isDeepARInitialized.value &&
          controller.isEffectShow.value) {
        return _EffectList(controller);
      }
      return const SizedBox();
    });
  }

  Widget _buildStopRecordingButton(CameraScreenController controller) {
    return Obx(() {
      final showStopButton =
          !controller.isRecording.value && controller.isStartingRecording.value;
      return Visibility(
        visible: showStopButton,
        replacement: const SizedBox(width: 37),
        child: CustomBorderRoundIcon(
          image: AssetRes.icCheck,
          onTap: controller.onVideoRecordingStop,
        ),
      );
    });
  }
}

class _EffectList extends StatelessWidget {
  final CameraScreenController controller;

  const _EffectList(this.controller);

  @override
  Widget build(BuildContext context) {
    final List<DeepARFilters> deepARFilters = controller.availableDeepArFilters;
    return SizedBox(
      height: 89,
      child: ListView.builder(
        itemCount: deepARFilters.length,
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          DeepARFilters effect = deepARFilters[index];

          return InkWell(
            onTap: () => controller.applyARFilterEffect(effect),
            child: Obx(() {
              final selected = controller.selectedEffect.value;
              final isSelected = (selected.id != null &&
                      effect.id != null &&
                      selected.id == effect.id) ||
                  (selected.filterFile != null &&
                      selected.filterFile == effect.filterFile);
              final borderColor =
                  whitePure(context).withAlpha(isSelected ? 255 : 76);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 79,
                height: 89,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Filter thumbnail
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: whitePure(context),
                          shape: BoxShape.circle,
                        ),
                        child: ClipSmoothRect(
                          radius: SmoothBorderRadius(cornerRadius: 30),
                          child: effect.id == -1
                              ? Image.asset(effect.image ?? '',
                                  height: 36, width: 36)
                              : _EffectThumbnail(imagePath: effect.image),
                        ),
                      ),
                    ),

                    // Filter name
                    Text(
                      effect.title ?? '',
                      style: TextStyleCustom.outFitLight300(
                        color: whitePure(context),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _RecordingDurationSelector extends StatelessWidget {
  const _RecordingDurationSelector();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CameraScreenController>();

    return Obx(() {
      final showSelector = !controller.isStartingRecording.value &&
          controller.isSecondListShow.value;

      if (!showSelector) return const SizedBox();

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.only(left: 5, right: 5, top: 20),
          child: Row(
            children: List.generate(
              controller.secondsList.length,
              (index) => _buildDurationItem(context, controller, index),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildDurationItem(
      BuildContext context, CameraScreenController controller, int index) {
    final second = controller.secondsList[index];

    return Obx(() {
      final isSelected = second == controller.selectedSecond.value;
      final textStyle = TextStyleCustom.outFitRegular400(
          color: whitePure(context), fontSize: 15);

      return InkWell(
        onTap: () => controller.selectedSecond.value = second,
        child: Container(
          height: 29,
          width: 60,
          decoration: isSelected
              ? ShapeDecoration(
                  color: whitePure(context).withAlpha(51),
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(cornerRadius: 30),
                    side: BorderSide(
                        color: whitePure(context).withAlpha(128), width: 0.5),
                  ))
              : null,
          alignment: Alignment.center,
          child: Text(_formatDurationLabel(second), style: textStyle),
        ),
      );
    });
  }

  String _formatDurationLabel(int second) {
    if (second < 60) return '${second}s';
    if (second % 60 == 0) return '${second ~/ 60}m';
    return '${second}s';
  }
}

class _EffectThumbnail extends StatelessWidget {
  final String? imagePath;

  const _EffectThumbnail({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return Image.asset(
        AssetRes.icNoFilter,
        height: 36,
        width: 36,
      );
    }

    if (_isAsset(imagePath!)) {
      return Image.asset(
        imagePath!,
        height: 36,
        width: 36,
      );
    }

    final uri = Uri.tryParse(imagePath!);
    final url = (uri != null && uri.hasScheme && uri.host.isNotEmpty)
        ? imagePath!
        : imagePath!.addBaseURL();

    return Image.network(
      url,
      height: 36,
      width: 36,
      errorBuilder: (_, __, ___) => Image.asset(AssetRes.icNoFilter),
    );
  }

  bool _isAsset(String path) =>
      path.startsWith('assets/') || path.startsWith('packages/');
}

class RecordingControlButton extends StatelessWidget {
  final CameraScreenController controller;

  const RecordingControlButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SizedBox(
        width: 70,
        height: 70,
        child: GestureDetector(
          onTap: controller.onPlayPauseToggle,
          onLongPressStart: (_) => controller.onPlayPauseToggle(type: 1),
          onLongPressEnd: (_) => controller.onPlayPauseToggle(type: 2),
          child: CustomPaint(
            painter: DashedCirclePainter(
                controller.progress / controller.selectedSecond.value),
            child: Center(
              child: controller.isRecording.value
                  ? _buildStopIndicator(context)
                  : _buildRecordButton(),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStopIndicator(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: ShapeDecoration(
        color: whitePure(context),
        shape: SmoothRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 4, cornerSmoothing: 0.6),
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Container(
      width: 55,
      height: 55,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red,
      ),
    );
  }
}
