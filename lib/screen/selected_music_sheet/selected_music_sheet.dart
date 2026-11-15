import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/duration_extension.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/widget/bottom_sheet_top_view.dart';
import 'package:toptap/common/widget/custom_image.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/screen/selected_music_sheet/selected_music_sheet_controller.dart';
import 'package:toptap/screen/selected_music_sheet/widget/wave_slider.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class SelectedMusicSheet extends StatelessWidget {
  final SelectedMusic selectedMusic;
  final int totalVideoSecond;

  const SelectedMusicSheet(
      {super.key,
      required this.selectedMusic,
      required this.totalVideoSecond});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SelectedMusicSheetController(
        totalVideoSecond * 1000, selectedMusic));
    return Container(
        margin: EdgeInsets.only(
            top: AppBar().preferredSize.height * 2),
        decoration: ShapeDecoration(
            color: adaptiveBackground(context),
            shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.vertical(
                    top: SmoothRadius(
                        cornerRadius: 30,
                        cornerSmoothing: 1)))),
        child: Column(
          children: [
            BottomSheetTopView(
                title: LKey.selectMusic.tr,
                sideBtnVisibility: true),
            Expanded(
                child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  CustomImage(
                      size: const Size(130, 130),
                      image: selectedMusic.music?.image
                          ?.addBaseURL(),
                      cornerSmoothing: 1,
                      radius: 5),
                  const SizedBox(height: 12),
                  Text(selectedMusic.music?.title ?? '',
                      style:
                          TextStyleCustom.outFitMedium500(
                              color: adaptiveTextColor(
                                  context),
                              fontSize: 15)),
                  Text(
                    '${selectedMusic.music?.artist} • ${selectedMusic.music?.duration}',
                    style: TextStyleCustom.outFitLight300(
                        color: textLightGrey(context)),
                  ),
                  Obx(
                    () => AnimatedOpacity(
                      duration:
                          const Duration(milliseconds: 200),
                      opacity: controller.isPlaying.value
                          ? 0
                          : 1,
                      child: FittedBox(
                        child: Container(
                          height: 30,
                          margin: const EdgeInsets.only(
                              top: 22, bottom: 12),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 22),
                          decoration: ShapeDecoration(
                            color: bgMediumGrey(context),
                            shape: SmoothRectangleBorder(
                                borderRadius:
                                    SmoothBorderRadius(
                                        cornerRadius: 30)),
                          ),
                          alignment: Alignment.center,
                          child: Obx(
                            () => Text(
                              Duration(
                                      milliseconds: controller
                                          .audioStartInMilliSec
                                          .value)
                                  .printDuration,
                              style: TextStyleCustom
                                  .outFitRegular400(
                                      color:
                                          adaptiveTextColor(
                                              context)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Obx(
                    () {
                      final duration = controller
                          .durationInMilliSec.value;

                      // Ensure duration is valid
                      if (duration == null ||
                          duration.isNaN ||
                          duration.isInfinite ||
                          duration <= 0) {
                        return const LoaderWidget();
                      }

                      return WaveSlider(
                        controller: controller,
                        audioDuration: duration,
                        videoDuration: totalVideoSecond,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: controller.playPause,
                    child: Container(
                      height: 57,
                      width: 57,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bgMediumGrey(context)),
                      alignment: const Alignment(0.1, 0),
                      child: Obx(
                        () => Image.asset(
                          controller.isPlaying.value
                              ? AssetRes.icPause
                              : AssetRes.icPlay,
                          color: adaptiveTextColor(context),
                          width: 35,
                          height: 35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextButtonCustom(
                      onTap: controller.onContinueTap,
                      title: LKey.continueText.tr,
                      backgroundColor:
                          themeAccentSolid(context),
                      titleColor: whitePure(context),
                      borderSide: BorderSide(
                          color: whitePure(context),
                          width: 1))
                ],
              ),
            ))
          ],
        ));
  }
}
