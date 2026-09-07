import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_app_bar.dart';
import 'package:shortzz/screen/help_center_screen/help_center_controller.dart';
import 'package:shortzz/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HelpCenterController());
    
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: 'Help Center'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: AppBar().preferredSize.height),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Popular Topics Section
                  SettingLabel(title: "POPULAR TOPICS"),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icHeart,
                    title: "Getting Started",
                    onTap: () => controller.openGettingStarted(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icProfile,
                    title: "Account & Profile",
                    onTap: () => controller.openAccountHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icVideoCamera,
                    title: "Creating Content",
                    onTap: () => controller.openContentHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icEye_1,
                    title: "Privacy & Safety",
                    onTap: () => controller.openPrivacyHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icCoin,
                    title: "Earnings & Payments",
                    onTap: () => controller.openEarningsHelp(),
                  ),
                  
                  // Features Section
                  SettingLabel(title: "FEATURES"),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icliveicon,
                    title: "Live Streaming",
                    onTap: () => controller.openLiveStreamHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icMessage,
                    title: "Comments & Chat",
                    onTap: () => controller.openCommentsHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icFollow,
                    title: "Following & Followers",
                    onTap: () => controller.openFollowHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icHashtag,
                    title: "Hashtags & Discovery",
                    onTap: () => controller.openHashtagHelp(),
                  ),
                  
                  // Troubleshooting Section
                  SettingLabel(title: "TROUBLESHOOTING"),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icNoInternet,
                    title: "Connection Issues",
                    onTap: () => controller.openConnectionHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icVideoCamera,
                    title: "Video Upload Problems",
                    onTap: () => controller.openUploadHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icNotification_1,
                    title: "Notification Issues",
                    onTap: () => controller.openNotificationHelp(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icSpeaker,
                    title: "Audio Problems",
                    onTap: () => controller.openAudioHelp(),
                  ),
                  
                  // Contact Support Section
                  SettingLabel(title: "CONTACT SUPPORT"),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icChat_1,
                    title: "Live Chat Support",
                    onTap: () => controller.openLiveChat(),
                  ),
                  
                  SettingIconTextWithArrow(
                    icon: AssetRes.icMessage,
                    title: "Send Email",
                    onTap: () => controller.sendEmail(),
                  ),
                  
                  if (controller.hasPhoneSupport)
                    SettingIconTextWithArrow(
                      icon: AssetRes.icMessage,
                      title: "Call Support",
                      onTap: () => controller.callSupport(),
                    ),
                  
                  // Community Section
                  SettingLabel(title: "COMMUNITY"),

                  if (controller.hasCommunity)
                    SettingIconTextWithArrow(
                      icon: AssetRes.icChat,
                      title: "Community Forum",
                      onTap: () => controller.openForum(),
                    ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.ichelpicon,
                    title: "FAQ",
                    onTap: () => controller.openFAQ(),
                  ),
                ],
              ),
            ),
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
