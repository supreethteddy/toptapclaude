import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/custom_toggle.dart';
import 'package:toptap/screen/content_preferences_screen/content_preferences_controller.dart';
import 'package:toptap/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class ContentPreferencesScreen extends StatelessWidget {
  const ContentPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(ContentPreferencesController());

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: 'Content Preferences'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: AppBar().preferredSize.height),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Content Filtering Section
                  SettingLabel(title: "CONTENT FILTERING"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icEye_1,
                    title: "Hide Sensitive Content",
                    widget: CustomToggle(
                      isOn: controller.hideSensitiveContent,
                      onChanged:
                          controller.toggleSensitiveContent,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icBlock,
                    title: "Filter Inappropriate Comments",
                    widget: CustomToggle(
                      isOn: controller
                          .filterInappropriateComments,
                      onChanged: controller
                          .toggleInappropriateComments,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icMessage,
                    title: "Auto-mute Videos",
                    widget: CustomToggle(
                      isOn: controller.autoMuteVideos,
                      onChanged:
                          controller.toggleAutoMuteVideos,
                    ),
                  ),

                  // Content Discovery Section
                  SettingLabel(title: "CONTENT DISCOVERY"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icStar,
                    title: "Personalized Recommendations",
                    widget: CustomToggle(
                      isOn: controller
                          .personalizedRecommendations,
                      onChanged: controller
                          .togglePersonalizedRecommendations,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icLocation,
                    title: "Show Content from My Region",
                    widget: CustomToggle(
                      isOn: controller.showRegionalContent,
                      onChanged:
                          controller.toggleRegionalContent,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icHeart,
                    title: "Show Trending Content",
                    widget: CustomToggle(
                      isOn: controller.showTrendingContent,
                      onChanged:
                          controller.toggleTrendingContent,
                    ),
                  ),

                  // Content Types Section
                  SettingLabel(title: "CONTENT TYPES"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icMusic,
                    title: "Show Music Videos",
                    widget: CustomToggle(
                      isOn: controller.showMusicVideos,
                      onChanged:
                          controller.toggleMusicVideos,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icPlay,
                    title: "Show Gaming Content",
                    widget: CustomToggle(
                      isOn: controller.showGamingContent,
                      onChanged:
                          controller.toggleGamingContent,
                    ),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icBookmark,
                    title: "Show Educational Content",
                    widget: CustomToggle(
                      isOn:
                          controller.showEducationalContent,
                      onChanged: controller
                          .toggleEducationalContent,
                    ),
                  ),

                  // Age-Appropriate Content Section
                  SettingLabel(
                      title: "AGE-APPROPRIATE CONTENT"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icLock,
                    title: "Restricted Mode",
                    onTap: () => _showRestrictedModeDialog(
                        context, controller),
                    widget: Obx(() => Text(
                          controller.restrictedMode.value,
                          style: TextStyleCustom
                              .outFitRegular400(
                            fontSize: 14,
                            color: textLightGrey(context),
                          ),
                        )),
                  ),

                  // Reset Section
                  SettingLabel(title: "RESET"),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icDelete2,
                    title: "Reset Content Preferences",
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

  void _showRestrictedModeDialog(BuildContext context,
      ContentPreferencesController controller) {
    Get.dialog(
      AlertDialog(
        title: Text('Restricted Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRestrictedModeOption(
                'Off', 'Off', controller),
            _buildRestrictedModeOption(
                'Moderate', 'Moderate', controller),
            _buildRestrictedModeOption(
                'Strict', 'Strict', controller),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedModeOption(
      String title,
      String value,
      ContentPreferencesController controller) {
    return Obx(() => RadioListTile<String>(
          title: Text(title),
          value: value,
          groupValue: controller.restrictedMode.value,
          onChanged: (String? newValue) {
            if (newValue != null) {
              controller.setRestrictedMode(newValue);
              Get.back();
            }
          },
        ));
  }

  void _showResetDialog(BuildContext context,
      ContentPreferencesController controller) {
    Get.dialog(
      AlertDialog(
        title: Text('Reset Content Preferences'),
        content: Text(
            'Are you sure you want to reset all content preferences to default settings?'),
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
                'Content preferences have been reset to default settings',
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
