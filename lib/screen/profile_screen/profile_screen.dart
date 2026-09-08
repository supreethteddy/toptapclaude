import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/my_refresh_indicator.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/widget/profile_page_view.dart';
import 'package:shortzz/screen/profile_screen/widget/profile_tab_bar_view.dart';
import 'package:shortzz/screen/profile_screen/widget/profile_user_header.dart';
import 'package:shortzz/screen/settings_screen/settings_screen.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ProfileScreen extends StatelessWidget {
  final User? user;
  final bool isTopBarVisible;
  final bool isDashBoard;
  final Function(User? user)? onUserUpdate;

  const ProfileScreen(
      {super.key,
      this.user,
      this.isTopBarVisible = true,
      this.isDashBoard = false,
      this.onUserUpdate});

  @override
  Widget build(BuildContext context) {
    void _showSettingsBottomSheet(BuildContext context,
        ProfileScreenController controller) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(20)),
        ),
        backgroundColor: adaptiveBackground(context),
        builder: (context) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 +
                    MediaQuery.of(context)
                        .viewInsets
                        .bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.settings,
                      color: ColorRes.likeRed,
                    ),
                    title: Text(
                      "Settings",
                      style:
                          TextStyleCustom.outFitRegular400(
                        color: ColorRes.textlightGreenColor,
                        fontSize: 18,
                      ),
                    ),
                    onTap: () {
                      Get.back(); // Close bottom sheet
                      Get.to(() => SettingsScreen(
                          onUpdateUser:
                              controller.onUpdateUser));
                    },
                  ),
                  Divider(
                    color: adaptiveTextColor(context),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.wallet_outlined,
                      color: ColorRes.likeRed,
                    ),
                    title: Text(
                      "Balance",
                      style:
                          TextStyleCustom.outFitRegular400(
                        color: ColorRes.textlightGreenColor,
                        fontSize: 18,
                      ),
                    ),
                    onTap: () {
                      Get.back();
                      Get.to(
                          () => const CoinWalletScreen());
                    },
                  ),
                  Divider(
                    color: adaptiveTextColor(context),
                  ),
                  // ListTile(
                  //   leading: const Icon(
                  //     Icons.phone_in_talk,
                  //     color: Colors.blue,
                  //   ),
                  //   title: Text(
                  //     "🧪 Call Tester",
                  //     style:
                  //         TextStyleCustom.outFitRegular400(
                  //       color: ColorRes.textlightGreenColor,
                  //       fontSize: 18,
                  //     ),
                  //   ),
                  //   onTap: () {
                  //     Get.back();
                  //     Get.to(() => const AgoraCallTester());
                  //   },
                  // ),
                  // ListTile(
                  //   leading: const Icon(
                  //     Icons.videocam,
                  //     color: Colors.green,
                  //   ),
                  //   title: Text(
                  //     "📹 Video Views Test",
                  //     style:
                  //         TextStyleCustom.outFitRegular400(
                  //       color: ColorRes.textlightGreenColor,
                  //       fontSize: 18,
                  //     ),
                  //   ),
                  //   onTap: () {
                  //     Get.back();
                  //     Get.to(() => const VideoViewsTest());
                  //   },
                  // ),
                  const SizedBox(height: 10),
                  //const QuickCallTester(),
                ],
              ),
            ),
          );
        },
      );
    }

    // void _showTestingBottomSheet(BuildContext context,
    //     ProfileScreenController controller) {
    //   showModalBottomSheet(
    //     context: context,
    //     isScrollControlled: true,
    //     shape: const RoundedRectangleBorder(
    //       borderRadius: BorderRadius.vertical(
    //           top: Radius.circular(20)),
    //     ),
    //     backgroundColor: adaptiveBackground(context),
    //     builder: (context) {
    //       return SafeArea(
    //         child: SingleChildScrollView(
    //           scrollDirection: Axis.vertical,
    //           padding: EdgeInsets.only(
    //             left: 20,
    //             right: 20,
    //             top: 20,
    //             bottom: 20 +
    //                 MediaQuery.of(context)
    //                     .viewInsets
    //                     .bottom,
    //           ),
    //           child: Column(
    //             mainAxisSize: MainAxisSize.min,
    //             children: [
    //               Container(
    //                 width: 50,
    //                 height: 5,
    //                 decoration: BoxDecoration(
    //                   color: Colors.grey[300],
    //                   borderRadius:
    //                       BorderRadius.circular(10),
    //                 ),
    //               ),
    //               const SizedBox(height: 20),
    //               Text(
    //                 "🧪 Testing Tools",
    //                 style: TextStyleCustom.outFitRegular400(
    //                   color: ColorRes.textlightGreenColor,
    //                   fontSize: 20,
    //                 ),
    //               ),
    //               const SizedBox(height: 20),
    //               ListTile(
    //                 leading: const Icon(
    //                   Icons.phone_in_talk,
    //                   color: Colors.blue,
    //                 ),
    //                 title: Text(
    //                   "📞 Call Tester",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: ColorRes.textlightGreenColor,
    //                     fontSize: 18,
    //                   ),
    //                 ),
    //                 subtitle: Text(
    //                   "Test audio/video calls with token input",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: Colors.grey[600],
    //                     fontSize: 14,
    //                   ),
    //                 ),
    //                 onTap: () {
    //                   Get.back();
    //                   Get.to(() => const AgoraCallTester());
    //                 },
    //               ),
    //               Divider(
    //                   color: adaptiveTextColor(context)),
    //               ListTile(
    //                 leading: const Icon(
    //                   Icons.videocam,
    //                   color: Colors.green,
    //                 ),
    //                 title: Text(
    //                   "📹 Video Views Test",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: ColorRes.textlightGreenColor,
    //                     fontSize: 18,
    //                   ),
    //                 ),
    //                 subtitle: Text(
    //                   "Test video rendering and camera feeds",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: Colors.grey[600],
    //                     fontSize: 14,
    //                   ),
    //                 ),
    //                 onTap: () {
    //                   Get.back();
    //                   Get.to(() => const VideoViewsTest());
    //                 },
    //               ),
    //               Divider(
    //                   color: adaptiveTextColor(context)),
    //               ListTile(
    //                 leading: const Icon(
    //                   Icons.call_received,
    //                   color: Colors.orange,
    //                 ),
    //                 title: Text(
    //                   "📲 Incoming Audio Call",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: ColorRes.textlightGreenColor,
    //                     fontSize: 18,
    //                   ),
    //                 ),
    //                 subtitle: Text(
    //                   "Test incoming call notification UI",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: Colors.grey[600],
    //                     fontSize: 14,
    //                   ),
    //                 ),
    //                 onTap: () {
    //                   Get.back();
    //                   testIncomingCall(isVideo: false);
    //                 },
    //               ),
    //               ListTile(
    //                 leading: const Icon(
    //                   Icons.video_call,
    //                   color: Colors.purple,
    //                 ),
    //                 title: Text(
    //                   "📺 Incoming Video Call",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: ColorRes.textlightGreenColor,
    //                     fontSize: 18,
    //                   ),
    //                 ),
    //                 subtitle: Text(
    //                   "Test incoming video call notification",
    //                   style:
    //                       TextStyleCustom.outFitRegular400(
    //                     color: Colors.grey[600],
    //                     fontSize: 14,
    //                   ),
    //                 ),
    //                 onTap: () {
    //                   Get.back();
    //                   testIncomingCall(isVideo: true);
    //                 },
    //               ),
    //               const SizedBox(height: 20),
    //               Container(
    //                 padding: const EdgeInsets.all(16),
    //                 decoration: BoxDecoration(
    //                   color: Colors.blue[50],
    //                   borderRadius:
    //                       BorderRadius.circular(12),
    //                   border: Border.all(
    //                       color: Colors.blue[200]!),
    //                 ),
    //                 child: Column(
    //                   children: [
    //                     const Icon(Icons.info,
    //                         color: Colors.blue),
    //                     const SizedBox(height: 8),
    //                     Text(
    //                       "Quick Testing Panel",
    //                       style: TextStyleCustom
    //                           .outFitRegular400(
    //                         color: Colors.blue[800],
    //                         fontSize: 14,
    //                       ),
    //                     ),
    //                     const SizedBox(height: 4),
    //                     Text(
    //                       "Test all calling features and debug issues",
    //                       style: TextStyleCustom
    //                           .outFitRegular400(
    //                         color: Colors.blue[600],
    //                         fontSize: 12,
    //                       ),
    //                       textAlign: TextAlign.center,
    //                     ),
    //                   ],
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       );
    //     },
    //   );
    // }

    ProfileScreenController controller = Get.put(
        ProfileScreenController(user.obs, onUserUpdate),
        tag: isDashBoard
            ? ProfileScreenController.tag
            : "${DateTime.now().millisecondsSinceEpoch}");

    return Scaffold(
      key: controller.scaffoldKey,
      // Add floating action button for easy testing
      // floatingActionButton:
      //     SessionManager.instance.getUser()?.id == user?.id
      //         ? FloatingActionButton(
      //             onPressed: () {
      //               _showTestingBottomSheet(
      //                   context, controller);
      //             },
      //             backgroundColor: Colors.blue,
      //             child: const Icon(Icons.bug_report,
      //                 color: Colors.white),
      //           )
      //         : null,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Center(
          child: Text(
            controller.userData.value?.fullname ?? "<name>",
            style: TextStyleCustom.outFitRegular400(
              color: ColorRes.likeRed,
              fontSize: 18,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showSettingsBottomSheet(
                context, controller),
          ),
        ],
        iconTheme: const IconThemeData(
          color: ColorRes.likeRed,
        ),
      ),
      // endDrawer: SettingsScreen(
      //     onUpdateUser: controller.onUpdateUser),
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) {},
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Obx(() => _TopViewForOtherUser(
                  user: controller.userData.value,
                  isTopBarVisible: false,
                  controller: controller)),
              Expanded(
                child: Stack(
                  children: [
                    Obx(() => DefaultTabController(
                          length: controller.tabLength,
                          child: MyRefreshIndicator(
                            depth: 2,
                            onRefresh: controller.onRefresh,
                            child: NestedScrollView(
                              headerSliverBuilder:
                                  (context, _) {
                                return [
                                  SliverList(
                                    delegate:
                                        SliverChildListDelegate([
                                      ProfileUserHeader(
                                          controller:
                                              controller)
                                    ]),
                                  ),
                                ];
                              },
                              body: Column(
                                children: [
                                  ProfileTabs(
                                      controller:
                                          controller),
                                  ProfilePageView(
                                      controller:
                                          controller)
                                ],
                              ),
                            ),
                          ),
                        )),
                    Obx(() {
                      User? user =
                          controller.userData.value;
                      if (user?.isFreez != 1) {
                        return const SizedBox();
                      }
                      return Container(
                        color:
                            scaffoldBackgroundColor(context)
                                .withValues(alpha: 0.4),
                        child: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: 30, sigmaY: 30),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                    Icons
                                        .lock_person_rounded,
                                    size: 80,
                                    color: textLightGrey(
                                        context)),
                                const SizedBox(height: 20),
                                Text(
                                  LKey.profileUnavailable
                                      .tr,
                                  style: TextStyleCustom
                                      .unboundedSemiBold600(
                                          color:
                                              textLightGrey(
                                                  context),
                                          fontSize: 18),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 30.0),
                                  child: Text(
                                    LKey.profileTemporarilyFrozen
                                        .tr,
                                    textAlign:
                                        TextAlign.center,
                                    style: TextStyleCustom
                                        .outFitMedium500(
                                            color:
                                                textLightGrey(
                                                    context),
                                            fontSize: 16),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Obx(() {
                                  bool isModerator =
                                      SessionManager
                                              .instance
                                              .isModerator
                                              .value ==
                                          1;
                                  if (!isModerator) {
                                    return const SizedBox();
                                  }
                                  return TextButtonCustom(
                                    onTap: () => controller
                                        .freezeUnfreezeUser(
                                            true),
                                    title: LKey.unFreeze.tr,
                                    titleColor:
                                        whitePure(context),
                                    backgroundColor:
                                        textDarkGrey(
                                            context),
                                  );
                                })
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopViewForOtherUser extends StatelessWidget {
  final User? user;
  final bool isTopBarVisible;
  final ProfileScreenController controller;

  const _TopViewForOtherUser(
      {this.user,
      required this.isTopBarVisible,
      required this.controller});

  @override
  Widget build(BuildContext context) {
    return isTopBarVisible
        ? Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              // comment code

              CustomBackButton(
                onTap: Get.back,
                padding: const EdgeInsets.all(15),
              ),

              //coment code

              const Flexible(child: SizedBox()

                  // Padding(
                  //   padding: const EdgeInsets.symmetric(
                  //       horizontal: 10.0),
                  //   child: Text(
                  //     user?.username ?? '',
                  //     style:
                  //         TextStyleCustom.unboundedMedium500(
                  //             color: textDarkGrey(context)),
                  //     overflow: TextOverflow.ellipsis,
                  //   ),
                  // ),
                  ),
              const SizedBox(width: 18 + 30),
            ],
          )
        : const SizedBox();
  }
}
