import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/theme_controller.dart';
import 'package:shortzz/common/widget/custom_app_bar.dart';
import 'package:shortzz/common/widget/custom_drop_down.dart';
import 'package:shortzz/common/widget/custom_toggle.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/accessibility_settings_screen/accessibility_settings_screen.dart';
import 'package:shortzz/screen/battle_history_screen/battle_history_screen.dart';
import 'package:shortzz/screen/notification_screen/notification_screen.dart';
import 'package:shortzz/screen/blocked_user_screen/blocked_user_screen.dart';
import 'package:shortzz/screen/content_preferences_screen/content_preferences_screen.dart';
import 'package:shortzz/screen/edit_profile_screen/edit_profile_screen.dart';
import 'package:shortzz/screen/help_center_screen/help_center_screen.dart';
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:shortzz/screen/playback_settings_screen/playback_settings_screen.dart';
import 'package:shortzz/screen/qr_code_screen/qr_code_screen.dart';
import 'package:shortzz/screen/saved_post_screen/saved_post_screen.dart';
import 'package:shortzz/screen/settings_screen/settings_screen_controller.dart';
import 'package:shortzz/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:shortzz/screen/settings_screen/notification_settings_screen/notification_settings_screen.dart';
import 'package:shortzz/screen/settings_screen/localization_screen/localization_screen.dart';
import 'package:shortzz/screen/subscription_screen/subscription_screen.dart';
import 'package:shortzz/screen/term_and_privacy_screen/term_and_privacy_screen.dart';

import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/screen/switch_account_screen/switch_account_screen.dart';
import 'package:shortzz/utilities/theme_res.dart';

class SettingsScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;

  const SettingsScreen({super.key, this.onUpdateUser});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsScreenController());
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: LKey.settings.tr),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: AppBar().preferredSize.height,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // 🎯 PROMINENT AR FILTER TEST SECTION - DISABLED (removed TopTap SDK)
                  /* Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF8B5CF6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF6366F1,
                          ).withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        print(
                          '🎯 Opening REAL AR Filter Test Screen...',
                        );
                        try {
                          Get.to(
                            () =>
                                const ARFilterTestScreen(),
                          );
                        } catch (e) {
                          print('Navigation error: $e');
                          // Show error to user
                          Get.snackbar(
                            'Error',
                            'Failed to open AR Filter screen: $e',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(
                              12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.camera_front,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "🎯 AR Filter Testing",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Test face filters like Snapchat/Instagram",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ), */

                  // SettingLabel(
                  //   title: "Development & Testing"
                  //       .toUpperCase(),
                  // ),
                  // AR Filters (backup location) - DISABLED (removed TopTap SDK)
                  /* SettingIconTextWithArrow(
                    icon: AssetRes.iccameraicon,
                    title: "Real AR Filters Test",
                    onTap: () {
                      try {
                        Get.to(
                          () => const ARFilterTestScreen(),
                        );
                      } catch (e) {
                        print('Navigation error: $e');
                      }
                    },
                  ), */
                  // SubscriptionCard(
                  //     controller: controller,
                  //     onUpdateUser: onUpdateUser),
                  SettingLabel(
                    // title: LKey.personal.toUpperCase(),
                    title: "Account".toUpperCase(),
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icProfile,
                    title: "Manage my account",
                    onTap: () {
                      Get.to(
                        () => EditProfileScreen(
                          onUpdateUser: onUpdateUser,
                        ),
                      );
                    },
                  ),

                  SettingIconTextWithArrow(
                    // icon: AssetRes.icQrCode_1,
                    icon: AssetRes.icShare,
                    title: "Share profile",
                    onTap: () {
                      Get.to(() => const QrCodeScreen());
                    },
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icliveicon,
                    title: "Live",
                    onTap: () {
                      Get.to(
                        () => const CreateLiveStreamScreen(),
                      );
                    },
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icBattleVs,
                    title: "Battle History",
                    onTap: () {
                      Get.to(
                        () => const BattleHistoryScreen(),
                      );
                    },
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.iccameraicon,
                    title: "Content preferences",
                    onTap: () {
                      Get.to(() =>
                          const ContentPreferencesScreen());
                    },
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icDelete2,
                    title: LKey.deleteAccount,
                    onTap: controller.onDeleteAccount,
                    widget: const SizedBox(),
                  ),
                  SettingLabel(
                    title: LKey.general.toUpperCase(),
                  ),

                  SettingIconTextWithArrow(
                    icon: AssetRes.icNotification_1,
                    title: 'Push Notifications',
                    onTap: () {
                      Get.to(
                        () => const NotificationSettingsScreen(),
                      );
                    },
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icMoon, // use any appropriate icon
                    title: 'Theme',
                    widget: Obx(() {
                      final themeController = Get.find<ThemeController>();
                      return CustomToggle(
                        isOn: themeController.isDarkModeRx,
                        onChanged: (val) {
                          themeController.toggleTheme(val);
                        },
                      );
                    }),
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icLanguage_1,
                    title: LKey.languages,
                    onTap: () {
                      Get.to(
                        () => const LocalizationScreen(),
                      );
                    },
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icactivityicon,
                    title: 'Activity',
                    onTap: () {
                      Get.to(
                        () => const NotificationScreen(showBackButton: true),
                      );
                    },
                  ),
                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icplaybackicon,
                  //   title: 'Play Back',
                  //   onTap: () {
                  //     Get.to(
                  //         () => const PlaybackSettingsScreen());
                  //   },
                  // ),
                  // SettingIconTextWithArrow(
                  //   icon: AssetRes.icaccessibilityicon,
                  //   title: 'Accessibility',
                  //   onTap: () {
                  //     Get.to(() =>
                  //         const AccessibilitySettingsScreen());
                  //   },
                  // ),
                  SettingLabel(
                    title: LKey.privacy.toUpperCase(),
                  ),
                  Obx(
                    () => SettingIconTextWithArrow(
                      icon: AssetRes.icEye_1,
                      title: LKey.whoCanSeePosts,
                      widget: CustomDropDownBtn<WhoCanSeePost>(
                        items: WhoCanSeePost.values,
                        onChanged: controller.isUpdateApiCalled.value
                            ? null
                            : controller.onChangedWhoCanSeePost,
                        selectedValue: controller.selectedWhoCanSeePost.value,
                        style: TextStyleCustom.outFitRegular400(
                          fontSize: 15,
                          color: textLightGrey(context),
                        ),
                        getTitle: (value) => value.title,
                      ),
                    ),
                  ),
                  Obx(() {
                    return SettingIconTextWithArrow(
                      icon: AssetRes.icEye_1,
                      title: LKey.showMyFollowings,
                      widget: CustomToggle(
                        isOn:
                            (controller.myUser.value?.showMyFollowing == 1).obs,
                        onChanged: (value) {
                          controller.onChangedToggle(
                            value,
                            SettingToggle.showMyFollowings,
                          );
                        },
                      ),
                    );
                  }),
                  Obx(() {
                    return SettingIconTextWithArrow(
                      icon: AssetRes.icMessage,
                      title: LKey.showChatBtn,
                      widget: CustomToggle(
                        isOn:
                            (controller.myUser.value?.receiveMessage == 1).obs,
                        onChanged: (value) async {
                          controller.onChangedToggle(
                            value,
                            SettingToggle.receiveMessage,
                          );
                        },
                      ),
                    );
                  }),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icPostBookmark,
                    title: LKey.savedPosts,
                    onTap: () {
                      Get.to(() => const SavedPostScreen());
                    },
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icBlock,
                    title: LKey.blockedUsers,
                    onTap: () {
                      Get.to(
                        () => const BlockedUserScreen(),
                      );
                    },
                  ),

                  SettingLabel(
                    title: "Support".toUpperCase(),
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icreporticon,
                    title: "Report a Problem",
                    onTap: () {
                      Get.to(() => const HelpCenterScreen());
                    },
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.ichelpicon,
                    title: "Help Center",
                    onTap: () {
                      Get.to(
                        () => const HelpCenterScreen(),
                      );
                    },
                  ),
                  // Call Notification Test Button (for testing purposes)
                  // SettingIconTextWithArrow(
                  //   icon: AssetRes
                  //       .icNotification_1, // Using notification icon
                  //   title: "Test Call Notifications",
                  //   onTap: () {
                  //     Get.to(
                  //       () =>
                  //           const CallNotificationTestScreen(),
                  //     );
                  //   },
                  // ),
                  // Real Call Demo Button (for client demos)
                  // SettingIconTextWithArrow(
                  //   icon: AssetRes
                  //       .icVideoCamera, // Using video camera icon
                  //   title: "🔥 Live Call Demo",
                  //   onTap: () {
                  //     Get.to(
                  //       () => const RealCallDemoScreen(),
                  //     );
                  //   },
                  // ),
                  // Real FCM Testing Button (for cross-device testing)
                  // SettingIconTextWithArrow(
                  //   icon: AssetRes
                  //       .icNotification_1, // Using notification icon
                  //   title: "🚀 Real FCM Testing",
                  //   onTap: () {
                  //     Get.to(
                  //       () => const FcmRealTestScreen(),
                  //     );
                  //   },
                  // ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icpoliciesicon,
                    title: "Terms and Policies",
                    onTap: () {
                      Get.to(
                        () => const TermAndPrivacyScreen(
                          type: TermAndPrivacyType.termAndCondition,
                        ),
                      );
                    },
                  ),
                  SettingLabel(
                    title: "Login".toUpperCase(),
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icLogout,
                    title: LKey.logOut,
                    onTap: controller.onLogout,
                    widget: const SizedBox(),
                  ),
                  SettingIconTextWithArrow(
                    icon: AssetRes.icSwitchAccount,
                    title: "Switch Account",
                    onTap: () {
                      Get.to(
                        () => const SwitchAccountScreen(),
                      );
                    },
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

class SubscriptionCard extends StatefulWidget {
  final SettingsScreenController controller;
  final Function(User? user)? onUpdateUser;

  const SubscriptionCard({
    super.key,
    required this.controller,
    this.onUpdateUser,
  });

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      bool isVerify = widget.controller.myUser.value?.isVerify == 1;
      return InkWell(
        onTap: () {
          if (!isVerify) {
            Get.to<bool>(
              () => SubscriptionScreen(
                onUpdateUser: widget.onUpdateUser,
              ),
            )?.then((value) {
              if (value == true) {
                widget.controller.myUser.update(
                  (val) => val?.isVerify = 1,
                );
              }
            });
          }
        },
        child: Container(
          height: 47,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
          ),
          margin: const EdgeInsets.all(5),
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: 7,
                cornerSmoothing: 1,
              ),
            ),
            gradient: StyleRes.themeGradient,
          ),
          child: Row(
            spacing: 11,
            children: [
              Image.asset(
                AssetRes.icPro,
                width: 24,
                height: 24,
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: isVerify ? LKey.youAre.tr : LKey.become.tr,
                    style: TextStyleCustom.outFitRegular400(
                      color: whitePure(context),
                      fontSize: 15,
                    ),
                    children: [
                      TextSpan(
                        text: ' ${LKey.plus.tr} ',
                        style: TextStyleCustom.outFitExtraBold800(
                          color: whitePure(context),
                          fontSize: 15,
                        ),
                      ),
                      TextSpan(
                        text: isVerify ? LKey.member.tr : '',
                        style: TextStyleCustom.outFitRegular400(
                          color: whitePure(context),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isVerify)
                Image.asset(
                  AssetRes.icForwardArrow,
                  width: 24,
                  height: 20,
                  color: whitePure(context),
                ),
            ],
          ),
        ),
      );
    });
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
        title.tr.toUpperCase(),
        style: TextStyleCustom.outFitMedium500(
          fontSize: 13,
          color: textLightGrey(context),
        ).copyWith(letterSpacing: 2),
      ),
    );
  }
}
