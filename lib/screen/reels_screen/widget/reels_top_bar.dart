// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shortzz/common/manager/session_manager.dart';
// import 'package:shortzz/common/widget/custom_back_button.dart';
// import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
// import 'package:shortzz/utilities/asset_res.dart';
// import 'package:shortzz/utilities/theme_res.dart';

// class ReelsTopBar extends StatelessWidget {
//   final ReelsScreenController controller;
//   final Widget? widget;

//   const ReelsTopBar(
//       {super.key, required this.controller, this.widget});

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         SafeArea(
//           bottom: false,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(
//                 horizontal: 15.0),
//             child: Row(
//               mainAxisAlignment:
//                   MainAxisAlignment.spaceBetween,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Visibility(
//                   visible: !controller.isHomePage,
//                   replacement: const SizedBox(width: 30),
//                   child: CustomBackButton(
//                       color: whitePure(context),
//                       height: 30,
//                       width: 30,
//                       padding: EdgeInsets.zero,
//                       image: AssetRes.icBackArrow_1),
//                 ),
//                 if (widget != null)
//                   Flexible(child: widget!),
//                 Obx(() {
//                   if (controller.reels.isEmpty) {
//                     return const SizedBox(
//                         width: 30, height: 30);
//                   }

//                   bool isVisible = controller
//                           .reels[controller.position.value]
//                           .userId !=
//                       SessionManager.instance.getUserID();

//                   return Visibility(
//                     // visible: isVisible,
//                     visible: false,
//                     replacement: const SizedBox(
//                         width: 30, height: 30),
//                     child: InkWell(
//                       onTap: controller.onReportTap,
//                       child: Image.asset(AssetRes.icAlert,
//                           width: 30, height: 30),
//                     ),
//                   );
//                 })
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:shortzz/screen/reels_screen/reels_screen_controller.dart';
import 'package:shortzz/screen/home_screen/home_screen_controller.dart';
import 'package:shortzz/screen/search_screen/search_screen.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class ReelsTopBar extends StatelessWidget {
  final ReelsScreenController controller;
  final Widget? widget;

  const ReelsTopBar({
    super.key,
    required this.controller,
    this.widget,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 15.0),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                // Back button (if not home page)
                // Visibility(
                //   visible: !controller.isHomePage,
                //   replacement: const SizedBox(width: 30),
                //   child: CustomBackButton(
                //     color: whitePure(context),
                //     height: 30,
                //     width: 30,
                //     padding: EdgeInsets.zero,
                //     image: AssetRes.icBackArrow_1,
                //   ),
                // ),
                IconButton(
                  onPressed: () {
                    // here we should go to create live screen
                    Get.to(() =>
                        const CreateLiveStreamScreen());
                  },
                  icon: const Icon(
                    Icons.live_tv_outlined,
                    color: Colors.white,
                  ),
                ),
                // Center tab bar
                const Expanded(
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Spacer(),
                      _NavTab(
                          label: 'Following',
                          tabType: TabType.following),
                      Spacer(),
                      _NavTab(
                          label: 'For You',
                          tabType: TabType.discover),
                      Spacer(),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const SearchScreen()),
                    );
                  },
                  icon: Icon(
                    Icons.search,
                    color: whitePure(context),
                    size: 28,
                  ),
                ),

                // Report icon (hidden)
                // Obx(
                //   () {
                //     if (controller.reels.isEmpty) {
                //       return const SizedBox(
                //           width: 30, height: 30);
                //     }

                //     bool isVisible = controller
                //             .reels[
                //                 controller.position.value]
                //             .userId !=
                //         SessionManager.instance.getUserID();

                // return Visibility(
                //   visible: false,
                //   replacement: const SizedBox(
                //       width: 30, height: 30),
                //   child: InkWell(
                //     onTap: controller.onReportTap,
                //     child: Image.asset(
                //       AssetRes.icAlert,
                //       width: 30,
                //       height: 30,
                //     ),
                //   ),
                // );
                //   },
                //  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final TabType tabType;

  const _NavTab({
    required this.label,
    required this.tabType,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeScreenController>();
    return Obx(() {
      final isSelected =
          controller.selectedReelCategory.value == tabType;

      return InkWell(
        onTap: () {
          if (tabType == TabType.nearby) {
            // Navigate to live stream screen when "Live" tab is tapped
            Get.to(() => const LiveStreamSearchScreen());
          } else {
            // Normal tab switching logic
            controller.onTabTypeChanged(tabType);
          }
        },
        child: Text(
          label,
          style: TextStyleCustom.unboundedBold700(
            fontSize: 19,
            color: isSelected
                ? whitePure(context)
                : whitePure(context).withOpacity(0.4),
          ),
        ),
      );
    });
  }
}

// class _NavTab extends StatelessWidget {
//   final String label;
//   final TabType tabType;

//   const _NavTab({
//     required this.label,
//     required this.tabType,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.find<HomeScreenController>();
//     return Obx(() {
//       final isSelected =
//           controller.selectedReelCategory.value == tabType;
//       return InkWell(
//         onTap: () => controller.onTabTypeChanged(tabType),
//         child: Text(
//           label,
//           style: TextStyleCustom.unboundedBold700(
//             fontSize: 19,
//             color: isSelected
//                 ? whitePure(context)
//                 : whitePure(context).withOpacity(0.4),
//           ),
//         ),
//       );
//     });
//   }
// }
