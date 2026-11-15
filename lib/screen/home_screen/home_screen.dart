// import 'package:figma_squircle_updated/figma_squircle.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:toptap/common/widget/custom_divider.dart';
// import 'package:toptap/screen/home_screen/home_screen_controller.dart';
// import 'package:toptap/screen/reels_screen/reels_screen.dart';
// import 'package:toptap/utilities/app_res.dart';
// import 'package:toptap/utilities/asset_res.dart';
// import 'package:toptap/utilities/text_style_custom.dart';
// import 'package:toptap/utilities/theme_res.dart';

// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.put(HomeScreenController());
//     return Scaffold(
//       backgroundColor: themeColor(context),
//       body: Stack(
//         children: [
//           ReelsScreen(
//             isHomePage: true,
//             reels: controller.reels,
//             position: 0,
//             isLoading: controller.isLoading,
//             onFetchMoreData: () => controller.onRefreshPage(reset: false),
//             widget: HomeTopCenterWidget(controller: controller),
//             onRefresh: controller.onRefreshPage,
//           ),
//           Obx(
//             () => GestureDetector(
//               onTap: !controller.isAnimateTab.value
//                   ? null
//                   : controller.onAnimationBack,
//               child: Container(
//                   color: !controller.isAnimateTab.value
//                       ? null
//                       : Colors.black.withValues(alpha: 0.5)),
//             ),
//           ),
//           SafeArea(
//             minimum: EdgeInsets.only(top: AppBar().preferredSize.height * 1.5),
//             child: SizeTransition(
//               sizeFactor: controller.animation,
//               axis: Axis.vertical,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 15.0),
//                 child: Column(
//                   children: [
//                     Center(
//                       child: CustomPaint(
//                         painter: TrianglePainter(
//                             strokeColor: whitePure(context),
//                             strokeWidth: 0,
//                             paintingStyle: PaintingStyle.fill),
//                         child: const SizedBox(height: 9, width: 15),
//                       ),
//                     ),
//                     Container(
//                       width: MediaQuery.of(context).size.width,
//                       constraints: const BoxConstraints(maxHeight: 200),
//                       decoration: ShapeDecoration(
//                         color: whitePure(context),
//                         shape: SmoothRectangleBorder(
//                           borderRadius: SmoothBorderRadius(
//                               cornerRadius: 8, cornerSmoothing: 1),
//                         ),
//                       ),
//                       child: ListView.builder(
//                         primary: false,
//                         shrinkWrap: true,
//                         padding: EdgeInsets.zero,
//                         itemCount: TabType.values.length,
//                         itemBuilder: (context, index) {
//                           TabType tabType = TabType.values[index];
//                           return Obx(() {
//                             bool isSelected =
//                                 controller.selectedReelCategory.value ==
//                                     tabType;
//                             return Column(
//                               children: [
//                                 InkWell(
//                                   onTap: () =>
//                                       controller.onTabTypeChanged(tabType),
//                                   child: Container(
//                                     height: 25,
//                                     margin: const EdgeInsets.symmetric(
//                                         vertical: 8.0, horizontal: 15),
//                                     child: Row(
//                                       children: [
//                                         Expanded(
//                                           child: Text(
//                                             tabType.title.toUpperCase(),
//                                             style: TextStyleCustom
//                                                 .unboundedBold700(
//                                                     fontSize: 14,
//                                                     color: isSelected
//                                                         ? textDarkGrey(context)
//                                                         : textLightGrey(
//                                                             context)),
//                                           ),
//                                         ),
//                                         if (isSelected)
//                                           Image.asset(AssetRes.icCheckCircle,
//                                               color: isSelected
//                                                   ? textDarkGrey(context)
//                                                   : textLightGrey(context),
//                                               height: 24,
//                                               width: 24),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 if (index < TabType.values.length - 1)
//                                   const CustomDivider(),
//                               ],
//                             );
//                           });
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }

// class HomeTopCenterWidget extends StatelessWidget {
//   final HomeScreenController controller;

//   const HomeTopCenterWidget({super.key, required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: controller.onToggleDropDown,
//       child: SafeArea(
//         bottom: false,
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Obx(() => Text(
//                 controller.selectedReelCategory.value.title.toUpperCase(),
//                 style: TextStyleCustom.unboundedBold700(
//                     fontSize: 16, color: whitePure(context)))),
//             const SizedBox(width: 5),
//             Image.asset(AssetRes.icDownArrow,
//                 color: whitePure(context), height: 12, width: 12),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class TrianglePainter extends CustomPainter {
//   final Color strokeColor;
//   final PaintingStyle paintingStyle;
//   final double strokeWidth;

//   TrianglePainter(
//       {this.strokeColor = Colors.black,
//       this.strokeWidth = 3,
//       this.paintingStyle = PaintingStyle.stroke});

//   @override
//   void paint(Canvas canvas, Size size) {
//     Paint paint = Paint()
//       ..color = strokeColor
//       ..strokeWidth = strokeWidth
//       ..style = paintingStyle;

//     canvas.drawPath(getTrianglePath(size.width, size.height), paint);
//   }

//   Path getTrianglePath(double x, double y) {
//     return Path()
//       ..moveTo(0, y)
//       ..lineTo(x / 2, 0)
//       ..lineTo(x, y)
//       ..lineTo(0, y);
//   }

//   @override
//   bool shouldRepaint(TrianglePainter oldDelegate) {
//     return oldDelegate.strokeColor != strokeColor ||
//         oldDelegate.paintingStyle != paintingStyle ||
//         oldDelegate.strokeWidth != strokeWidth;
//   }
// }

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_divider.dart';
import 'package:toptap/screen/home_screen/home_screen_controller.dart';
import 'package:toptap/screen/reels_screen/reels_screen.dart';
import 'package:toptap/screen/search_screen/search_screen.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeScreenController());
    return Scaffold(
      //  extendBody: true,
      backgroundColor: themeColor(context),
      //backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ReelsScreen(
                  isHomePage: true,
                  reels: controller.reels,
                  position: 0,
                  isLoading: controller.isLoading,
                  onFetchMoreData: () => controller
                      .onRefreshPage(reset: false),
                  widget:
                      const SizedBox(), // HIDDEN: HomeTopCenterWidget, now moved to top nav
                  onRefresh: controller.onRefreshPage,
                ),
              ),
            ],
          ),
          Obx(
            () => GestureDetector(
              onTap: !controller.isAnimateTab.value
                  ? null
                  : controller.onAnimationBack,
              child: Container(
                  color: !controller.isAnimateTab.value
                      ? null
                      : Colors.black.withOpacity(0.5)),
            ),
          ),
          // HIDDEN: Old dropdown menu logic (keep logic intact but hide from view)
          Positioned(
            top: -500,
            left: 0,
            right: 0,
            child: Offstage(
              offstage: true, // or false based on logic
              child: SafeArea(
                minimum: EdgeInsets.only(
                  top: AppBar().preferredSize.height * 1.5,
                ),
                child: SizeTransition(
                  sizeFactor: controller.animation,
                  axis: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15.0),
                    child: Column(
                      children: [
                        Center(
                          child: CustomPaint(
                            painter: TrianglePainter(
                              strokeColor:
                                  whitePure(context),
                              strokeWidth: 0,
                              paintingStyle:
                                  PaintingStyle.fill,
                            ),
                            child: const SizedBox(
                                height: 9, width: 15),
                          ),
                        ),
                        Container(
                          width: MediaQuery.of(context)
                              .size
                              .width,
                          constraints: const BoxConstraints(
                              maxHeight: 200),
                          decoration: ShapeDecoration(
                            color: whitePure(context),
                            shape: SmoothRectangleBorder(
                              borderRadius:
                                  SmoothBorderRadius(
                                cornerRadius: 8,
                                cornerSmoothing: 1,
                              ),
                            ),
                          ),
                          child: ListView.builder(
                            primary: false,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount:
                                TabType.values.length,
                            itemBuilder: (context, index) {
                              TabType tabType =
                                  TabType.values[index];
                              return Obx(() {
                                bool isSelected = controller
                                        .selectedReelCategory
                                        .value ==
                                    tabType;
                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () => controller
                                          .onTabTypeChanged(
                                              tabType),
                                      child: Container(
                                        height: 25,
                                        margin:
                                            const EdgeInsets
                                                .symmetric(
                                                vertical:
                                                    8.0,
                                                horizontal:
                                                    15),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tabType
                                                    .title
                                                    .toUpperCase(),
                                                style: TextStyleCustom
                                                    .unboundedBold700(
                                                  fontSize:
                                                      14,
                                                  color: isSelected
                                                      ? textDarkGrey(
                                                          context)
                                                      : textLightGrey(
                                                          context),
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              Image.asset(
                                                AssetRes
                                                    .icCheckCircle,
                                                color: isSelected
                                                    ? textDarkGrey(
                                                        context)
                                                    : textLightGrey(
                                                        context),
                                                height: 24,
                                                width: 24,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (index <
                                        TabType.values
                                                .length -
                                            1)
                                      const CustomDivider(),
                                  ],
                                );
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          //  const HomeTopNavBar(), // ADDED: Top nav bar (Live, Following, For You, Search)
        ],
      ),
    );
  }
}

// // ADDED: Top bar widget
// class HomeTopNavBar extends StatelessWidget {
//   const HomeTopNavBar({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.find<HomeScreenController>();
//     return SafeArea(
//       bottom: false,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(
//             horizontal: 10.0, vertical: 8),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 _NavTab(
//                     label: 'Live', tabType: TabType.nearby),
//                 SizedBox(width: 12),
//                 _NavTab(
//                     label: 'Following',
//                     tabType: TabType.following),
//                 SizedBox(width: 12),
//                 _NavTab(
//                     label: 'For You',
//                     tabType: TabType.discover),
//               ],
//             ),
//             const SizedBox(
//               width: 30,
//             ),
//             InkWell(
//               onTap: () {
//                 Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                         builder: (context) =>
//                             const SearchScreen()));
//               },
//               child: Image.asset(AssetRes.icSearch,
//                   width: 20,
//                   height: 20,
//                   color: whitePure(context)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _NavTab extends StatelessWidget {
//   final String label;
//   final TabType tabType;

//   const _NavTab(
//       {required this.label, required this.tabType});

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
//             fontSize: 14,
//             color: isSelected
//                 ? whitePure(context)
//                 : whitePure(context).withOpacity(0.4),
//           ),
//         ),
//       );
//     });
//   }
// }

class TrianglePainter extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  TrianglePainter(
      {this.strokeColor = Colors.transparent,
      this.strokeWidth = 3,
      this.paintingStyle = PaintingStyle.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = paintingStyle;

    canvas.drawPath(
        getTrianglePath(size.width, size.height), paint);
  }

  Path getTrianglePath(double x, double y) {
    return Path()
      ..moveTo(0, y)
      ..lineTo(x / 2, 0)
      ..lineTo(x, y)
      ..lineTo(0, y);
  }

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.paintingStyle != paintingStyle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
// NOTE: HomeTopCenterWidget was removed visually but logic exists in dropdown.
