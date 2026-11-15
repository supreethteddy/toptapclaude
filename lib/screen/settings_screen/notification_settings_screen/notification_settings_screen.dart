import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/custom_toggle.dart';
import 'package:toptap/screen/settings_screen/notification_settings_screen/notification_settings_screen_controller.dart';
import 'package:toptap/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NotificationSettingsScreenController>(
      init: NotificationSettingsScreenController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: bgLightGrey(context),
          body: Column(
            children: [
              CustomAppBar(title: "Notification Settings".tr),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // General Notifications Section
                      _buildSectionTitle(context, "General".tr),
                      const SizedBox(height: 10),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icNotification,
                        title: "Push Notifications".tr,
                        widget: CustomToggle(
                          isOn: controller.pushNotifications,
                          onChanged: controller.togglePushNotifications,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icVoice,
                        title: "Sound".tr,
                        widget: CustomToggle(
                          isOn: controller.soundEnabled,
                          onChanged: controller.toggleSound,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icSpeaker,
                        title: "Vibration".tr,
                        widget: CustomToggle(
                          isOn: controller.vibrationEnabled,
                          onChanged: controller.toggleVibration,
                        ),
                      ),

                      const SizedBox(height: 30),
                      
                      // Activity Notifications Section
                      _buildSectionTitle(context, "Activity".tr),
                      const SizedBox(height: 10),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icHeart,
                        title: "Likes".tr,
                        widget: CustomToggle(
                          isOn: controller.likesNotifications,
                          onChanged: controller.toggleLikes,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icComment,
                        title: "Comments".tr,
                        widget: CustomToggle(
                          isOn: controller.commentsNotifications,
                          onChanged: controller.toggleComments,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icaddfriend,
                        title: "New Followers".tr,
                        widget: CustomToggle(
                          isOn: controller.followersNotifications,
                          onChanged: controller.toggleFollowers,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icAt,
                        title: "Mentions".tr,
                        widget: CustomToggle(
                          isOn: controller.mentionsNotifications,
                          onChanged: controller.toggleMentions,
                        ),
                      ),

                      const SizedBox(height: 30),
                      
                      // Live & Social Section
                      _buildSectionTitle(context, "Live & Social".tr),
                      const SizedBox(height: 10),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icLive,
                        title: "Live Streams".tr,
                        widget: CustomToggle(
                          isOn: controller.liveNotifications,
                          onChanged: controller.toggleLive,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icGift,
                        title: "Gifts".tr,
                        widget: CustomToggle(
                          isOn: controller.giftsNotifications,
                          onChanged: controller.toggleGifts,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icMessage,
                        title: "Direct Messages".tr,
                        widget: CustomToggle(
                          isOn: controller.messagesNotifications,
                          onChanged: controller.toggleMessages,
                        ),
                      ),

                      const SizedBox(height: 30),
                      
                      // Marketing Section
                      _buildSectionTitle(context, "Marketing".tr),
                      const SizedBox(height: 10),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icCoin,
                        title: "Promotional Offers".tr,
                        widget: CustomToggle(
                          isOn: controller.promotionalNotifications,
                          onChanged: controller.togglePromotional,
                        ),
                      ),
                      
                      SettingIconTextWithArrow(
                        icon: AssetRes.icDownload,
                        title: "App Updates".tr,
                        widget: CustomToggle(
                          isOn: controller.updatesNotifications,
                          onChanged: controller.toggleUpdates,
                        ),
                      ),

                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyleCustom.outFitSemiBold600(
          fontSize: 16,
          color: textDarkGrey(context),
        ),
      ),
    );
  }
}
