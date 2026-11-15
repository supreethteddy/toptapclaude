import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/custom_toggle.dart';
import 'package:toptap/screen/playback_settings_screen/playback_settings_controller.dart';
import 'package:toptap/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(PlaybackSettingsController());

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: 'Playback Settings'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: AppBar().preferredSize.height),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Video Quality Section
                  SettingLabel(title: "VIDEO QUALITY"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icVideoCamera,
                    title: "Default Video Quality",
                    widget: Obx(() => Text(
                          controller
                              .videoQuality.value.title,
                          style: TextStyleCustom
                              .outFitRegular400(
                                  fontSize: 15,
                                  color: textLightGrey(
                                      context)),
                        )),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icHeart,
                    title: "Auto Quality",
                    widget: CustomToggle(
                      isOn: controller.autoQuality,
                      onChanged:
                          controller.toggleAutoQuality,
                    ),
                  ),

                  // Audio Settings Section
                  SettingLabel(title: "AUDIO SETTINGS"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icSpeaker,
                    title: "Auto-play with Sound",
                    widget: CustomToggle(
                      isOn: controller.autoPlayWithSound,
                      onChanged: controller
                          .toggleAutoPlayWithSound,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icSpeaker,
                    title: "Reduce Loud Sounds",
                    widget: CustomToggle(
                      isOn: controller.reduceLoudSounds,
                      onChanged:
                          controller.toggleReduceLoudSounds,
                    ),
                  ),

                  // Playback Controls Section
                  SettingLabel(title: "PLAYBACK CONTROLS"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icPlay,
                    title: "Auto-play Videos",
                    widget: CustomToggle(
                      isOn: controller.autoPlayVideos,
                      onChanged:
                          controller.toggleAutoPlayVideos,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icHeart,
                    title: "Loop Videos",
                    widget: CustomToggle(
                      isOn: controller.loopVideos,
                      onChanged:
                          controller.toggleLoopVideos,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icVideoCamera,
                    title: "Show Playback Speed Control",
                    widget: CustomToggle(
                      isOn: controller
                          .showPlaybackSpeedControl,
                      onChanged: controller
                          .toggleShowPlaybackSpeedControl,
                    ),
                  ),

                  // // Data Usage Section
                  // SettingLabel(title: "DATA USAGE"),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icHeart,
                  //   title: "Data Saver Mode",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.dataSaverMode,
                  //     onChanged: controller.toggleDataSaverMode,
                  //   )),
                  // ),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icVideoCamera,
                  //   title: "Only use WiFi for HD",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.wifiOnlyHD,
                  //     onChanged: controller.toggleWifiOnlyHD,
                  //   )),
                  // ),

                  // // Subtitles & Captions Section
                  // SettingLabel(title: "SUBTITLES & CAPTIONS"),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icText,
                  //   title: "Auto-show Captions",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.autoShowCaptions,
                  //     onChanged: controller.toggleAutoShowCaptions,
                  //   )),
                  // ),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icText,
                  //   title: "Caption Size",
                  //   widget: Obx(() => CustomDropDownBtn<CaptionSize>(
                  //     items: CaptionSize.values,
                  //     onChanged: controller.setCaptionSize,
                  //     selectedValue: controller.captionSize.value,
                  //     style: TextStyleCustom.outFitRegular400(
                  //         fontSize: 15,
                  //         color: textLightGrey(context)),
                  //     getTitle: (value) => value.title,
                  //   )),
                  // ),

                  // // Performance Section
                  // SettingLabel(title: "PERFORMANCE"),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icVideoCamera,
                  //   title: "Hardware Acceleration",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.hardwareAcceleration,
                  //     onChanged: controller.toggleHardwareAcceleration,
                  //   )),
                  // ),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icVideoCamera,
                  //   title: "Preload Next Video",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.preloadNextVideo,
                  //     onChanged: controller.togglePreloadNextVideo,
                  //   )),
                  // ),

                  // Reset Section
                  SettingLabel(title: "RESET"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icDelete2,
                    title: "Reset Playback Settings",
                    onTap: () => _showResetDialog(
                        context, controller),
                    widget: const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context,
      PlaybackSettingsController controller) {
    Get.dialog(
      AlertDialog(
        title: Text('Reset Playback Settings'),
        content: Text(
            'Are you sure you want to reset all playback settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.resetToDefaults();
              Get.back();
              Get.snackbar(
                'Reset Complete',
                'Playback settings have been reset to default values',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class SettingLabel extends StatelessWidget {
  final String title;

  const SettingLabel({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      width: double.infinity,
      color: bgMediumGrey(context),
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        title,
        style: TextStyleCustom.outFitMedium500(
                fontSize: 13, color: textLightGrey(context))
            .copyWith(letterSpacing: 2),
      ),
    );
  }
}
