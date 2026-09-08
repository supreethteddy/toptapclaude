// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:proste_indexed_stack/proste_indexed_stack.dart';
// // import 'package:shortzz/common/widget/gradient_border.dart';
// import 'package:shortzz/common/widget/gradient_icon.dart';
// import 'package:shortzz/model/user_model/user_model.dart';
// import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
// import 'package:shortzz/screen/explore_screen/explore_screen.dart';
// import 'package:shortzz/screen/feed_screen/feed_screen.dart';
// import 'package:shortzz/screen/home_screen/home_screen.dart';
// import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
// import 'package:shortzz/screen/message_screen/message_screen.dart';
// import 'package:shortzz/screen/profile_screen/profile_screen.dart';
// import 'package:shortzz/utilities/style_res.dart';
// import 'package:shortzz/utilities/text_style_custom.dart';
// import 'package:shortzz/utilities/theme_res.dart';

// class DashboardScreen extends StatelessWidget {
//   final User? myUser;

//   const DashboardScreen({super.key, this.myUser});

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.put(DashboardScreenController());
//     return Scaffold(
//       backgroundColor: scaffoldBackgroundColor(context),
//       resizeToAvoidBottomInset: true,
//       body: Obx(() {
//         return Column(
//           children: [
//             Expanded(
//               child: ProsteIndexedStack(
//                 index: controller.selectedPageIndex.value,
//                 children: [
//                   IndexedStackChild(child: const HomeScreen(), preload: true),
//                   IndexedStackChild(
//                       child: FeedScreen(myUser: myUser), preload: true),
//                   IndexedStackChild(
//                       child: const LiveStreamSearchScreen(), preload: true),
//                   IndexedStackChild(
//                       child: const ExploreScreen(), preload: true),
//                   IndexedStackChild(
//                       child: const MessageScreen(), preload: true),
//                   IndexedStackChild(
//                       child: ProfileScreen(
//                           isDashBoard: true,
//                           user: myUser,
//                           isTopBarVisible: false),
//                       preload: true)
//                 ],
//               ),
//             ),
//             if (controller.selectedPageIndex.value != 0)
//               const BannerAdsCustom(),
//           ],
//         );
//       }),
//       bottomNavigationBar: _buildBottomNavigationBar(context, controller),
//     );
//   }

//   Widget _buildBottomNavigationBar(
//       BuildContext context, DashboardScreenController controller) {
//     return Obx(() {
//       PostUploadingProgress postUpload = controller.postProgress.value;
//       bool isPostUploading =
//           postUpload.uploadType == UploadType.none ? false : true;
//       return AnimatedContainer(
//         duration: const Duration(milliseconds: 100),
//         color: blackPure(context),
//         padding: const EdgeInsets.only(top: 5),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: List.generate(
//                 controller.bottomIconList.length,
//                 (index) {
//                   return _buildBottomNavItem(
//                       context, controller, index, isPostUploading);
//                 },
//               ),
//             ),
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 100),
//               height: isPostUploading ? 30 : 0,
//               margin: Platform.isAndroid || !isPostUploading
//                   ? EdgeInsets.zero
//                   : const EdgeInsets.only(bottom: 20, top: 5),
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   Container(
//                       height: 30,
//                       decoration:
//                           BoxDecoration(gradient: StyleRes.themeGradient)),
//                   Align(
//                     alignment: AlignmentDirectional.centerEnd,
//                     child: LayoutBuilder(builder: (context, constraints) {
//                       double progress =
//                           (constraints.maxWidth * postUpload.progress) / 100;
//                       return AnimatedContainer(
//                         height: 30,
//                         width: constraints.maxWidth - progress,
//                         duration: const Duration(milliseconds: 250),
//                         decoration: BoxDecoration(color: textDarkGrey(context)),
//                       );
//                     }),
//                   ),
//                   Align(
//                     alignment: Alignment.center,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         if (postUpload.uploadType != UploadType.error)
//                           Text('${postUpload.progress.toInt()}%',
//                               style: TextStyleCustom.outFitMedium500(
//                                 color: whitePure(context),
//                                 fontSize: 16,
//                               )),
//                         Text(' ${postUpload.uploadType.title(postUpload.type)}',
//                             style: TextStyleCustom.outFitLight300(
//                                 color: whitePure(context), fontSize: 14)),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           ],
//         ),
//       );
//     });
//   }

//   Widget _buildBottomNavItem(BuildContext context,
//       DashboardScreenController controller, int index, bool isPostUploading) {
//     return Obx(() {
//       final isSelected = controller.selectedPageIndex.value == index;
//       final scaleValue = isSelected ? controller.scaleValue.value : 1.0;

//       return SafeArea(
//         bottom: isPostUploading ? false : true,
//         child: GradientBorder(
//           onPressed: () => controller.onChanged(index),
//           strokeWidth: isSelected ? 2 : 0,
//           radius: 30,
//           gradient: isSelected ? StyleRes.themeGradient : null,
//           child: Padding(
//             padding: const EdgeInsets.all(3),
//             child: AnimatedScale(
//               scale: scaleValue,
//               duration: const Duration(milliseconds: 300),
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   GradientIcon(
//                     gradient:
//                         isSelected ? null : StyleRes.textDarkGreyGradient(),
//                     child: Image.asset(controller.bottomIconList[index],
//                         height: 38, width: 38),
//                   ),
//                   if (index == 4) _buildUnreadCount(controller, context),
//                   // Moved to a separate function
//                 ],
//               ),
//             ),
//           ),
//         ),
//       );
//     });
//   }

//   Widget _buildUnreadCount(
//       DashboardScreenController controller, BuildContext context) {
//     return Obx(() {
//       final count = controller.unReadCount.value;
//       return count > 0
//           ? Text(count > 9 ? '9+' : '$count',
//               style: TextStyleCustom.outFitRegular400(
//                   color: whitePure(context), fontSize: 12))
//           : const SizedBox();
//     });
//   }
// }

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proste_indexed_stack/proste_indexed_stack.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/gradient_border.dart';
import 'package:shortzz/common/widget/gradient_icon.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/explore_screen/explore_screen.dart';
//import 'package:shortzz/screen/feed_screen/feed_screen.dart';
import 'package:shortzz/screen/home_screen/home_screen.dart';
//import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:shortzz/screen/message_screen/message_screen.dart';
import 'package:shortzz/screen/notification_screen/notification_screen.dart';
import 'package:shortzz/screen/profile_screen/profile_screen.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/widget/post_options_sheet.dart';
import 'package:shortzz/screen/settings_screen/widget/notifications_page.dart';
//import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class DashboardScreen extends StatelessWidget {
  final User? myUser;

  const DashboardScreen({super.key, this.myUser});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardScreenController());
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      resizeToAvoidBottomInset: true,
      body: Obx(() {
        return Column(
          children: [
            Expanded(
              child: ProsteIndexedStack(
                index: controller.selectedPageIndex.value,
                children: [
                  IndexedStackChild(
                      child: const HomeScreen(),
                      preload: true),

                  // IndexedStackChild(child: FeedScreen(myUser: myUser), preload: true),
                  // IndexedStackChild(child: const LiveStreamSearchScreen(), preload: true),

                  IndexedStackChild(
                      //child: const ExploreScreen(),
                      child: const MessageScreen(),
                      preload: true),
                  IndexedStackChild(
                      child: const SizedBox()),
                  IndexedStackChild(
                      child: const NotificationScreen(),
                      preload: true),
                  IndexedStackChild(
                      child: ProfileScreen(
                          isDashBoard: true,
                          user: myUser,
                          isTopBarVisible: false),
                      preload: true),
                ],
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar:
          _buildBottomNavigationBar(context, controller),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context,
      DashboardScreenController controller) {
    return Obx(() {
      PostUploadingProgress postUpload =
          controller.postProgress.value;
      bool isPostUploading =
          postUpload.uploadType == UploadType.none
              ? false
              : true;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: adaptiveBackground(context),
        padding: const EdgeInsets.only(top: 5, bottom: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
              children: List.generate(
                controller.bottomIconList.length,
                (index) {
                  final isCenter = index == 2;
                  return isCenter
                      ? GestureDetector(
                          onTap: () {
                            final user = SessionManager
                                .instance
                                .getUser(); // or pass from above
                            final profileController =
                                Get.put(
                              ProfileScreenController(
                                  user.obs, (user) {}),
                              tag: '${user?.id}',
                            );

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor:
                                  adaptiveBackground(
                                      context),
                              builder: (context) =>
                                  PostOptionsSheet(
                                      controller:
                                          profileController),
                            );
                          },
                          child: Container(
                            height: 55,
                            width: 55,
                            margin:
                                const EdgeInsets.symmetric(
                                    horizontal: 10),
                            // decoration: const BoxDecoration(
                            //     //  shape: BoxShape.circle,
                            //     // gradient:
                            //     //     StyleRes.themeGradient,
                            //     ),
                            child: Center(
                              child: Image.asset(
                                controller
                                    .bottomIconList[index],
                                height: 30,
                                width: 90,
                                // color: whitePure(context),
                              ),
                            ),
                          ),
                        )
                      : _buildBottomNavItem(
                          context,
                          controller,
                          index,
                          isPostUploading);
                },
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: isPostUploading ? 30 : 0,
              margin: Platform.isAndroid || !isPostUploading
                  ? EdgeInsets.zero
                  : const EdgeInsets.only(
                      bottom: 20, top: 5),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                        gradient: StyleRes.themeGradient),
                  ),
                  Align(
                    alignment:
                        AlignmentDirectional.centerEnd,
                    child: LayoutBuilder(
                        builder: (context, constraints) {
                      double progress =
                          (constraints.maxWidth *
                                  postUpload.progress) /
                              100;
                      return AnimatedContainer(
                        height: 30,
                        width:
                            constraints.maxWidth - progress,
                        duration: const Duration(
                            milliseconds: 250),
                        decoration: BoxDecoration(
                            color: textDarkGrey(context)),
                      );
                    }),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        if (postUpload.uploadType !=
                            UploadType.error)
                          Text(
                              '${postUpload.progress.toInt()}%',
                              style: TextStyleCustom
                                  .outFitMedium500(
                                color: whitePure(context),
                                fontSize: 16,
                              )),
                        Text(
                            ' ${postUpload.uploadType.title(postUpload.type)}',
                            style: TextStyleCustom
                                .outFitLight300(
                                    color:
                                        whitePure(context),
                                    fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    });
  }

  Widget _buildBottomNavItem(
      BuildContext context,
      DashboardScreenController controller,
      int index,
      bool isPostUploading) {
    return Obx(() {
      final isSelected =
          controller.selectedPageIndex.value == index;
      final scaleValue =
          isSelected ? controller.scaleValue.value : 1.0;

      return SafeArea(
        bottom: isPostUploading ? false : true,
        child: GradientBorder(
          onPressed: () => controller.onChanged(index),
          strokeWidth: isSelected ? 0 : 0,
          radius: 30,
          gradient:
              isSelected ? StyleRes.themeGradient : null,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: AnimatedScale(
              scale: scaleValue,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GradientIcon(
                    gradient: isSelected
                        ? null
                        //StyleRes.disabledGreyGradient()
                        // : StyleRes.textDarkGreyGradient(),
                        : StyleRes.disabledGreyGradient(),
                    child: Image.asset(
                      controller.bottomIconList[index],
                      height: 38,
                      width: 38,
                    ),
                  ),
                  if (index == 2)
                    _buildUnreadCount(controller, context),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildUnreadCount(
      DashboardScreenController controller,
      BuildContext context) {
    return Obx(() {
      final count = controller.unReadCount.value;
      return count > 0
          ? Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(count > 9 ? '9+' : '$count',
                    style: TextStyleCustom.outFitRegular400(
                        color: whitePure(context),
                        fontSize: 10)),
              ),
            )
          : const SizedBox();
    });
  }
}








  // Widget _buildBottomNavigationBar(BuildContext context,
  //     DashboardScreenController controller) {
  //   return Obx(() {
  //     PostUploadingProgress postUpload =
  //         controller.postProgress.value;
  //     bool isPostUploading =
  //         postUpload.uploadType == UploadType.none
  //             ? false
  //             : true;
  //     return AnimatedContainer(
  //       duration: const Duration(milliseconds: 100),
  //       color: blackPure(context),
  //       padding: const EdgeInsets.only(top: 5, bottom: 5),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Row(
  //             mainAxisAlignment:
  //                 MainAxisAlignment.spaceAround,
  //             children: List.generate(
  //               controller.bottomIconList.length,
  //               (index) {
  //                 final isCenter = index == 2;
  //                 return isCenter
  //                     ? GestureDetector(
  //                         onTap: () =>
  //                             controller.onChanged(index),
  //                         child: Container(
  //                           height: 55,
  //                           width: 55,
  //                           margin:
  //                               const EdgeInsets.symmetric(
  //                                   horizontal: 10),
  //                           decoration: BoxDecoration(
  //                             shape: BoxShape.circle,
  //                             gradient:
  //                                 StyleRes.themeGradient,
  //                           ),
  //                           child: Center(
  //                             child: Image.asset(
  //                               controller
  //                                   .bottomIconList[index],
  //                               height: 30,
  //                               width: 30,
  //                               color: whitePure(context),
  //                             ),
  //                           ),
  //                         ),
  //                       )
  //                     : _buildBottomNavItem(
  //                         context,
  //                         controller,
  //                         index,
  //                         isPostUploading);
  //               },
  //             ),
  //           ),
  //           AnimatedContainer(
  //             duration: const Duration(milliseconds: 100),
  //             height: isPostUploading ? 30 : 0,
  //             margin: Platform.isAndroid || !isPostUploading
  //                 ? EdgeInsets.zero
  //                 : const EdgeInsets.only(
  //                     bottom: 20, top: 5),
  //             child: Stack(
  //               alignment: Alignment.center,
  //               children: [
  //                 Container(
  //                     height: 30,
  //                     decoration: BoxDecoration(
  //                         gradient:
  //                             StyleRes.themeGradient)),
  //                 Align(
  //                   alignment:
  //                       AlignmentDirectional.centerEnd,
  //                   child: LayoutBuilder(
  //                       builder: (context, constraints) {
  //                     double progress =
  //                         (constraints.maxWidth *
  //                                 postUpload.progress) /
  //                             100;
  //                     return AnimatedContainer(
  //                       height: 30,
  //                       width:
  //                           constraints.maxWidth - progress,
  //                       duration: const Duration(
  //                           milliseconds: 250),
  //                       decoration: BoxDecoration(
  //                           color: textDarkGrey(context)),
  //                     );
  //                   }),
  //                 ),
  //                 Align(
  //                   alignment: Alignment.center,
  //                   child: Row(
  //                     mainAxisAlignment:
  //                         MainAxisAlignment.center,
  //                     crossAxisAlignment:
  //                         CrossAxisAlignment.center,
  //                     children: [
  //                       if (postUpload.uploadType !=
  //                           UploadType.error)
  //                         Text(
  //                             '${postUpload.progress.toInt()}%',
  //                             style: TextStyleCustom
  //                                 .outFitMedium500(
  //                               color: whitePure(context),
  //                               fontSize: 16,
  //                             )),
  //                       Text(
  //                           ' ${postUpload.uploadType.title(postUpload.type)}',
  //                           style: TextStyleCustom
  //                               .outFitLight300(
  //                                   color:
  //                                       whitePure(context),
  //                                   fontSize: 14)),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           )
  //         ],
  //       ),
  //     );
  //   });
  // }
