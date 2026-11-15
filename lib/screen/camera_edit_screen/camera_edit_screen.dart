import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_border_round_icon.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/screen/camera_edit_screen/camera_edit_screen_controller.dart';
import 'package:toptap/screen/camera_edit_screen/text_story/story_text_view.dart';
import 'package:toptap/screen/camera_edit_screen/widget/drawing_toolbar.dart';
import 'package:toptap/screen/camera_screen/camera_types.dart';
import 'package:toptap/screen/camera_screen/widget/camera_top_view.dart';
import 'package:toptap/screen/color_filter_screen/color_filter_view.dart';
import 'package:toptap/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';
import 'package:video_player/video_player.dart';

class CameraEditScreen extends StatelessWidget {
  final PostStoryContent content;
  final CameraScreenType screenType;

  const CameraEditScreen(
      {super.key,
      required this.content,
      this.screenType = CameraScreenType.story});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CameraEditScreenController(
        content.obs,
        screenType: screenType));
    return Scaffold(
      backgroundColor: adaptiveBackground(context),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6.0, vertical: 35),
                child: Stack(
                  clipBehavior: Clip
                      .none, // FIXED: Allow text to be dragged outside bounds without clipping
                  children: [
                    GenerateContentView(
                        controller: controller),
                    // FIXED: Use Align instead of Positioned to only capture touches in button areas
                    Align(
                      alignment: Alignment.topRight,
                      child: CameraEditTopViewTools(
                          controller: controller),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FilterAndMusicView(
                          controller: controller),
                    ),
                    // Drawing toolbar overlay
                    Obx(() {
                      if (!controller.isDrawingMode.value) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: DrawingToolbar(
                          selectedColor: controller
                              .selectedDrawColor.value,
                          selectedSize:
                              controller.brushSize.value,
                          isEraser:
                              controller.isEraser.value,
                          onUndo:
                              controller.undoDrawingStroke,
                          onRedo:
                              controller.redoDrawingStroke,
                          onClear:
                              controller.clearAllDrawings,
                          onDone:
                              controller.exitDrawingMode,
                          onColorSelected:
                              controller.setDrawingColor,
                          onSizeSelected:
                              controller.setBrushSize,
                          onEraserToggle:
                              controller.toggleEraser,
                          canUndo: controller
                              .drawingStrokes.isNotEmpty,
                          canRedo: controller
                              .redoStrokes.isNotEmpty,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            CameraEditActionButtons(controller: controller),
          ],
        ),
      ),
    );
  }
}

class GenerateContentView extends StatelessWidget {
  final CameraEditScreenController controller;

  const GenerateContentView(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return switch (controller.content.value.type) {
      PostStoryContentType.storyText ||
      PostStoryContentType.storyImage =>
        CameraEditImageView(
            cameraEditController: controller),
      PostStoryContentType.reel ||
      PostStoryContentType.storyVideo =>
        CameraEditVideoView(content: controller.content),
    };
  }
}

class CameraEditTopViewTools extends StatelessWidget {
  final CameraEditScreenController controller;

  const CameraEditTopViewTools(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    PostStoryContent content = controller.content.value;
    PostStoryContentType type = content.type;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        // crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 10,
        children: [
          // Obx(
          //   () {
          //     if (controller.videoPlayerController.value != null) {
          //       return ValueListenableBuilder(
          //         valueListenable: controller.videoPlayerController.value!,
          //         builder: (context, value, child) => CustomBorderRoundIcon(
          //           image: value.volume == 1.0
          //               ? AssetRes.icVolumeOn
          //               : AssetRes.icVolumeOff,
          //           onTap: controller.toggleVideoVolume,
          //         ),
          //       );
          //     } else {
          //       return const SizedBox();
          //     }
          //   },
          // ),
          if ([
            PostStoryContentType.storyImage,
            PostStoryContentType.storyText
          ].contains(type))
            Obx(
              () => CustomBorderRoundIcon(
                onTap: controller.changeStoryTime,
                widget: Center(
                  child: Text(
                      '${AppRes.storyDurations[controller.currentStoryDurationIndex.value]}s',
                      style: TextStyleCustom
                          .unboundedMedium500(
                              color: whitePure(context)),
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          if ([
            PostStoryContentType.storyImage,
            PostStoryContentType.storyText
          ].contains(type))
            Container(
              margin: const EdgeInsets.only(right: 10),
              child: CustomBorderRoundIcon(
                onTap: () =>
                    controller.onNewTexFieldAdd?.call(),
                image: AssetRes.icText1,
              ),
            ),
          // Sticker button (for images and text stories)
          if ([
            PostStoryContentType.storyImage,
            PostStoryContentType.storyText
          ].contains(type))
            Container(
              margin: const EdgeInsets.only(right: 10),
              child: CustomBorderRoundIcon(
                onTap: controller.onStickerTap,
                image: AssetRes.icSticker,
              ),
            ),
          // Drawing button (for images and text stories)
          if ([
            PostStoryContentType.storyImage,
            PostStoryContentType.storyText
          ].contains(type))
            Container(
              margin: const EdgeInsets.only(right: 10),
              child: Obx(() {
                final isActive =
                    controller.isDrawingMode.value;
                return CustomBorderRoundIcon(
                  onTap: controller.toggleDrawingMode,
                  widget: Icon(
                    Icons.brush,
                    color: isActive
                        ? themeAccentSolid(context)
                        : whitePure(context),
                    size: 23,
                  ),
                );
              }),
            ),
          // Filter button (not for text stories)
          if (![PostStoryContentType.storyText]
              .contains(content.type))
            CustomBorderRoundIcon(
                image: AssetRes.icFilter,
                onTap: controller.onFilterToggle),
          if ([
            PostStoryContentType.storyText,
            PostStoryContentType.storyImage
          ].contains(type))
            Obx(() {
              bool isTextStory =
                  PostStoryContentType.storyText == type;
              int selectedGradientIndex =
                  controller.selectedBgIndex.value;

              var gradient = isTextStory
                  ? controller.storyGradientColor[
                      selectedGradientIndex]
                  : controller.content.value.bgGradient;
              return CustomBorderRoundIcon(
                onTap: () =>
                    controller.changeBg(isTextStory),
                widget: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isTextStory
                          ? gradient
                          : controller
                              .content.value.bgGradient,
                      border: Border.all(
                          color: whitePure(context),
                          width: 2)),
                ),
              );
            }),
          CustomBorderRoundIcon(
              image: AssetRes.icMusic,
              onTap: controller.handleMusicSelection),
        ],
      ),
    );
  }
}

class FilterAndMusicView extends StatelessWidget {
  final CameraEditScreenController controller;

  const FilterAndMusicView(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      bool isFilterShow = controller.isFilterShow.value;
      PostStoryContent content = controller.content.value;
      SelectedMusic? music = content.sound;
      return Container(
        margin: const EdgeInsets.only(bottom: 15),
        child: Column(
          children: [
            AnimatedOpacity(
              opacity: isFilterShow ? 1 : 0,
              duration: const Duration(milliseconds: 100),
              child: IgnorePointer(
                ignoring: !isFilterShow,
                child: Padding(
                  padding:
                      const EdgeInsets.only(bottom: 20.0),
                  child: ColorFiltersView(
                      onPageChanged:
                          controller.changedFilter,
                      image: content.thumbNail),
                ),
              ),
            ),
            if (music != null)
              SelectedMusicView(
                  selectedMusic: music.obs,
                  isReelType: false,
                  onDeleteMusic: controller.onMusicDelete,
                  onMusicTap: (music) {
                    controller.handleMusicSelection(
                        initialMusic: music);
                  })
          ],
        ),
      );
    });
  }
}

class CameraEditVideoView extends StatelessWidget {
  final Rx<PostStoryContent> content;

  const CameraEditVideoView(
      {super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.find<CameraEditScreenController>();
    return Obx(() {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(
            controller.selectedFilter.value),
        child: Container(
          decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                      cornerRadius: 15,
                      cornerSmoothing: 1))),
          child: Obx(() => CustomVideoPlayer(
              videoPlayerController:
                  controller.videoPlayerController.value,
              onPlayPause: controller.onPlayPauseToggle)),
        ),
      );
    });
  }
}

class CustomVideoPlayer extends StatelessWidget {
  final VideoPlayerController? videoPlayerController;
  final VoidCallback onPlayPause;

  const CustomVideoPlayer(
      {super.key,
      required this.videoPlayerController,
      required this.onPlayPause});

  @override
  Widget build(BuildContext context) {
    if (videoPlayerController != null &&
        videoPlayerController!.value.isInitialized) {
      final videoSize = videoPlayerController!.value.size;
      final fitType = videoSize.width < videoSize.height
          ? BoxFit.cover
          : BoxFit.fitWidth;
      return InkWell(
        onTap: onPlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipSmoothRect(
              radius: SmoothBorderRadius(
                  cornerRadius: 15, cornerSmoothing: 1),
              child: Container(
                color: blackPure(context),
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: fitType,
                    child: SizedBox(
                        width: videoSize.width,
                        height: videoSize.height,
                        child: VideoPlayer(
                            videoPlayerController!)),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: videoPlayerController!,
              builder: (context, value, child) =>
                  AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: value.isPlaying ? 0 : 1,
                child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                        color: blackPure(context)
                            .withValues(alpha: 0.5),
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Image.asset(AssetRes.icPause,
                        width: 35,
                        height: 35,
                        color: bgGrey(context))),
              ),
            )
          ],
        ),
      );
    } else {
      return const LoaderWidget();
    }
  }
}

class CameraEditActionButtons extends StatelessWidget {
  final CameraEditScreenController controller;

  const CameraEditActionButtons(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Row(
        children: [
          Expanded(
            child: TextButtonCustom(
              onTap: controller.onDiscard,
              title: LKey.discard.tr,
              btnHeight: 44,
              backgroundColor: adaptiveBackground(context),
              titleColor: adaptiveTextColor(context),
              borderSide: BorderSide(
                color: adaptiveTextColor(context),
                width: 1,
              ),
              horizontalMargin: 10,
            ),
          ),
          Expanded(
            child: Obx(() {
              final isPosting =
                  controller.isMergingVideo.value ||
                      controller.isStoryUploading.value;

              if (isPosting) {
                return const LoaderWidget();
              }

              return TextButtonCustom(
                onTap: controller.handleContentUpload,
                title: LKey.post.tr,
                btnHeight: 44,
                backgroundColor:
                    themeAccentSolid(context),
                titleColor: Colors.white,
                borderSide: BorderSide(
                  color: adaptiveTextColor(context),
                  width: 1,
                ),
                horizontalMargin: 10,
              );
            }),
          ),
        ],
      ),
    );
  }
}
