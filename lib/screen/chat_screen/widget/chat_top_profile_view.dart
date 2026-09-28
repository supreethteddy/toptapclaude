// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shortzz/common/extensions/string_extension.dart';
// import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
// import 'package:shortzz/common/widget/custom_back_button.dart';
// import 'package:shortzz/common/widget/custom_image.dart';
// import 'package:shortzz/common/widget/custom_popup_menu_button.dart';
// import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
// import 'package:shortzz/languages/languages_keys.dart';
// import 'package:shortzz/model/chat/chat_thread.dart';
// import 'package:shortzz/model/livestream/app_user.dart';
// import 'package:shortzz/model/user_model/user_model.dart';
// import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
// import 'package:shortzz/utilities/asset_res.dart';
// import 'package:shortzz/utilities/text_style_custom.dart';
// import 'package:shortzz/utilities/theme_res.dart';

// class ChatTopProfileView extends StatelessWidget {
//   final ChatScreenController controller;

//   const ChatTopProfileView({super.key, required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: bgLightGrey(context),
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
//       child: SafeArea(
//         bottom: false,
//         child: Obx(() {
//           ChatThread chatThread = controller.conversationUser.value;
//           AppUser? chatUser = chatThread.chatUser;
//           bool iBlocked = chatThread.iBlocked ?? false;
//           return Row(
//             spacing: 10,
//             children: [
//               const CustomBackButton(image: AssetRes.icBackArrow_1),
//               Expanded(
//                 child: InkWell(
//                   onTap: () {
//                     User user = User(
//                       id: chatUser?.userId,
//                       fullname: chatUser?.fullname,
//                       username: chatUser?.username,
//                       profilePhoto: chatUser?.profile,
//                       isVerify: chatUser?.isVerify,
//                     );
//                     NavigationService.shared.openProfileScreen(
//                       user,
//                       onUserUpdate: (user) {
//                         if (controller.otherUser?.id == user?.id) {
//                           controller.otherUser = user;
//                         }
//                       },
//                     );
//                   },
//                   child: Row(
//                     spacing: 10,
//                     children: [
//                       CustomImage(
//                           size: const Size(48, 48),
//                           image: chatUser?.profile?.addBaseURL(),
//                           fullName: chatUser?.fullname),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             FullNameWithBlueTick(
//                                 username: chatUser?.username ?? '',
//                                 fontSize: 13,
//                                 iconSize: 18,
//                                 isVerify: chatUser?.isVerify),
//                             Text(chatUser?.fullname ?? '',
//                                 style: TextStyleCustom.outFitLight300(
//                                     color: textLightGrey(context),
//                                     fontSize: 15))
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               CustomPopupMenuButton(
//                   items: [
//                     MenuItem(
//                       iBlocked ? LKey.unBlock.tr : LKey.block.tr,
//                       () {
//                         controller.toggleBlockUnblock(chatThread);
//                       },
//                     ),
//                     MenuItem(
//                       LKey.report.tr,
//                       () {
//                         controller.onReportUser(chatThread);
//                       },
//                     ),
//                   ],
//                   child: Container(
//                       height: 36,
//                       width: 36,
//                       decoration: BoxDecoration(
//                           color: bgMediumGrey(context), shape: BoxShape.circle),
//                       alignment: Alignment.center,
//                       child:
//                           Image.asset(AssetRes.icMore, width: 25, height: 25)))
//             ],
//           );
//         }),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:shortzz/common/controller/live_status_controller.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/chat_screen/chat_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ChatTopProfileView extends StatelessWidget {
  final ChatScreenController controller;

  const ChatTopProfileView(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgLightGrey(context),
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 12),
      child: SafeArea(
        bottom: false,
        child: Obx(() {
          ChatThread chatThread =
              controller.conversationUser.value;
          AppUser? chatUser = chatThread.chatUser;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CustomBackButton(
                  image: AssetRes.icBackArrow_1),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  User user = User(
                    id: chatUser?.userId,
                    fullname: chatUser?.fullname,
                    username: chatUser?.username,
                    profilePhoto: chatUser?.profile,
                    isVerify: chatUser?.isVerify,
                  );
                  NavigationService.shared
                      .openProfileScreen(
                    user,
                    onUserUpdate: (user) {
                      if (controller.otherUser?.id ==
                          user?.id) {
                        controller.otherUser = user;
                      }
                    },
                  );
                },
                child: Row(
                  children: [
                    CustomImage(
                      size: const Size(48, 48),
                      image:
                          chatUser?.profile?.addBaseURL(),
                      fullName: chatUser?.fullname,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        FullNameWithBlueTick(
                          username:
                              chatUser?.username ?? '',
                          fontSize: 14,
                          iconSize: 16,
                          isVerify: chatUser?.isVerify,
                        ),
                        Obx(() {
                          bool isLive = LiveStatusController.to
                              .isLive(chatUser?.userId);
                          if (isLive) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin:
                                      const EdgeInsets.only(right: 5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ColorRes.likeRed,
                                  ),
                                ),
                                Text(
                                  LKey.inAStreamNow.tr,
                                  style: TextStyleCustom
                                      .outFitLight300(
                                    color: textLightGrey(context),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Text(
                            chatUser?.fullname ?? '',
                            style: TextStyleCustom
                                .outFitLight300(
                              color: textLightGrey(context),
                              fontSize: 15,
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Voice Call Icon
              IconButton(
                icon: const Icon(Icons.call,
                    color: Colors.red),
                onPressed: () {
                  controller.startVoiceCall(chatThread
                      .chatUser); // Make sure this exists
                },
              ),
              // Video Call Icon
              IconButton(
                icon: const Icon(Icons.videocam,
                    color: Colors.red),
                onPressed: () {
                  controller.startVideoCall(chatThread
                      .chatUser); // Make sure this exists
                },
              ),

              // COMMENTED: Popup Menu (Block / Report)
              /*
              CustomPopupMenuButton(
                items: [
                  MenuItem(
                    iBlocked ? LKey.unBlock.tr : LKey.block.tr,
                    () {
                      controller.toggleBlockUnblock(chatThread);
                    },
                  ),
                  MenuItem(
                    LKey.report.tr,
                    () {
                      controller.onReportUser(chatThread);
                    },
                  ),
                ],
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: bgMediumGrey(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(AssetRes.icMore, width: 25, height: 25),
                ),
              ),
              */
            ],
          );
        }),
      ),
    );
  }
}
