import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/custom_toggle.dart';
import 'package:toptap/screen/accessibility_settings_screen/accessibility_settings_controller.dart';
import 'package:toptap/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(AccessibilitySettingsController());

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: 'Accessibility'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: AppBar().preferredSize.height),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Vision Settings Section
                  SettingLabel(title: "VISION SETTINGS"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icEye_1,
                    title: "High Contrast Mode",
                    widget: CustomToggle(
                      isOn: controller.highContrastMode,
                      onChanged:
                          controller.toggleHighContrastMode,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icText,
                    title: "Large Text Size",
                    widget: CustomToggle(
                      isOn: controller.largeTextSize,
                      onChanged:
                          controller.toggleLargeTextSize,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icText,
                    title: "Font Size",
                    widget: Obx(() => Text(
                          controller.fontSize.value.title,
                          style: TextStyleCustom
                              .outFitRegular400(
                                  fontSize: 15,
                                  color: textLightGrey(
                                      context)),
                        )),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icText,
                    title: "Bold Text",
                    widget: CustomToggle(
                      isOn: controller.boldText,
                      onChanged: controller.toggleBoldText,
                    ),
                  ),

                  // Motor Settings Section
                  SettingLabel(title: "MOTOR SETTINGS"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icHeart,
                    title: "Touch Accommodations",
                    widget: CustomToggle(
                      isOn: controller.touchAccommodations,
                      onChanged: controller
                          .toggleTouchAccommodations,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icNotification_1,
                    title: "Vibration Feedback",
                    widget: CustomToggle(
                      isOn: controller.vibrationFeedback,
                      onChanged: controller
                          .toggleVibrationFeedback,
                    ),
                  ),

                  // Audio Settings Section
                  SettingLabel(title: "AUDIO SETTINGS"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icSpeaker,
                    title: "Audio Descriptions",
                    widget: CustomToggle(
                      isOn: controller.audioDescriptions,
                      onChanged: controller
                          .toggleAudioDescriptions,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icMusic,
                    title: "Mono Audio",
                    widget: CustomToggle(
                      isOn: controller.monoAudio,
                      onChanged: controller.toggleMonoAudio,
                    ),
                  ),

                  // // Navigation Settings Section
                  // SettingLabel(title: "NAVIGATION SETTINGS"),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icMicrophone,
                  //   title: "Voice Control",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.voiceControl,
                  //     onChanged: controller.toggleVoiceControl,
                  //   )),
                  // ),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icForwardArrow,
                  //   title: "Easy Swipe Navigation",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.easySwipeNavigation,
                  //     onChanged: controller.toggleEasySwipeNavigation,
                  //   )),
                  // ),

                  // // Screen Reader Section
                  // SettingLabel(title: "SCREEN READER"),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icEye_1,
                  //   title: "Enable Screen Reader",
                  //   widget: Obx(() => CustomToggle(
                  //     isOn: controller.screenReaderEnabled,
                  //     onChanged: controller.toggleScreenReader,
                  //   )),
                  // ),

                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icPlay,
                  //   title: "Screen Reader Speed",
                  //   widget: Obx(() => CustomDropDownBtn<ScreenReaderSpeed>(
                  //     items: ScreenReaderSpeed.values,
                  //     onChanged: controller.setScreenReaderSpeed,
                  //     selectedValue: controller.screenReaderSpeed.value,
                  //     style: TextStyleCustom.outFitRegular400(
                  //         fontSize: 15,
                  //         color: textLightGrey(context)),
                  //     getTitle: (value) => value.title,
                  //   )),
                  // ),

                  // Reset Section
                  SettingLabel(title: "RESET"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icDelete2,
                    title: "Reset Accessibility Settings",
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
      AccessibilitySettingsController controller) {
    Get.dialog(
      AlertDialog(
        title: Text('Reset Accessibility Settings'),
        content: Text(
            'Are you sure you want to reset all accessibility settings to default values?'),
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
                'Accessibility settings have been reset to default values',
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
