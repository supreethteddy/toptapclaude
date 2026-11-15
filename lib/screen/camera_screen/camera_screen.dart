import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/black_gradient_shadow.dart';
import 'package:toptap/common/widget/custom_border_round_icon.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/screen/camera_screen/camera_screen_controller.dart';
import 'package:toptap/screen/camera_screen/camera_types.dart';
import 'package:toptap/screen/camera_screen/widget/camera_bottom_view.dart';
// import 'package:toptap/screen/camera_screen/widget/camera_top_view.dart';
import 'package:toptap/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/theme_res.dart';

class CameraScreen extends StatelessWidget {
  final CameraScreenType cameraType;
  final SelectedMusic? selectedMusic;

  const CameraScreen({super.key, required this.cameraType, this.selectedMusic});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(CameraScreenController(cameraType, selectedMusic.obs));

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: blackPure(context),
        resizeToAvoidBottomInset: false,
        body: Stack(
          alignment: Alignment.center,
          children: [
            _buildCameraPreview(controller),
            const Align(
              alignment: Alignment.bottomCenter,
              child: BlackGradientShadow(
                height: 150,
              ),
            ),
            _buildCameraUI(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(CameraScreenController controller) {
    return AspectRatio(
      aspectRatio: 0.52,
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(cornerRadius: 20, cornerSmoothing: 1),
        child: Obx(() {
          DeepArControllerPlus deepArControllerPlus =
              controller.deepArControllerPlus.value;
          if (controller.isDeepARInitialized.value) {
            return Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 720,
                    height: 1280,
                    child: DeepArPreviewPlus(deepArControllerPlus),
                  ),
                ),
                const Positioned(
                  right: 12,
                  bottom: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xAA000000),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'deepar.ai',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (controller.deepArStatusMessage.value.isNotEmpty) {
            return ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    controller.deepArStatusMessage.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            );
          }

          return const LoaderWidget();
        }),
      ),
    );
  }

  Widget _buildCameraUI(
      BuildContext context, CameraScreenController controller) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // CameraTopView(cameraType: cameraType),
              // const SizedBox
              //     .shrink(), // Placeholder for top view
              CameraBottomView(cameraType: cameraType),
              const SizedBox(
                height: 20,
              ) // Placeholder for bottom view
            ],
          ),
          // Center-right action buttons
          _buildCenterRightButtons(controller),
        ],
      ),
    );
  }

  Widget _buildCenterRightButtons(CameraScreenController controller) {
    return Stack(
      children: [
        // Close button at top-left
        Positioned(
          top: 10,
          left: 17,
          child: SafeArea(
            child: CustomBorderRoundIcon(
              image: AssetRes.icClose,
              onTap: controller.onBackFromScreen,
            ),
          ),
        ),

        // Center-right action buttons
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 17),
            child: Obx(() {
              final isTorchOn = controller.isTorchOn.value;
              final shouldStartRecording = controller.isStartingRecording.value;

              return Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 15,
                children: [
                  // Flash toggle
                  CustomBorderRoundIcon(
                    onTap: controller.onToggleFlash,
                    image: isTorchOn ? AssetRes.icNoFlash : AssetRes.icFlash,
                  ),

                  // Camera flip (hidden during recording)
                  if (!shouldStartRecording)
                    CustomBorderRoundIcon(
                      onTap: controller.onToggleCamera,
                      image: AssetRes.icCameraFlip,
                    ),

                  // Music button (hidden when music is selected)
                  // if (isSelectedMusicEmpty)
                  //   CustomBorderRoundIcon(
                  //     onTap: controller.onMusicTap,
                  //     image: AssetRes.icMusic,
                  //   ),

                  // DeepAR Effects toggle
                  if (controller.isUsingDeepAr)
                    CustomBorderRoundIcon(
                      image: AssetRes.icStar,
                      onTap: controller.onEffectToggle,
                    ),

                  // Text story button removed - text editing available in edit screen after capture
                  // if (cameraType == CameraScreenType.story)
                  //   CustomBorderRoundIcon(
                  //     image: AssetRes.icText,
                  //     onTap: controller.onNavigateTextStory,
                  //   ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
