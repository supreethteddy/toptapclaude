import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/screen/profile_screen/profile_screen_controller.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/theme_res.dart';

class ProfileTabs extends StatelessWidget {
  final ProfileScreenController controller;

  const ProfileTabs({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Get icons based on whether it's own profile or not
    final isOwnProfile = controller.isOwnProfile;
    final icons = isOwnProfile
        ? [
            AssetRes.icReelicontab, // Reels
            AssetRes.icPost, // Posts
            AssetRes.icLock, // Private
            AssetRes.icHeart1, // Favorite
            AssetRes.icSave, // Saved
          ]
        : [
            AssetRes.icReelicontab, // Reels only
            AssetRes.icPost, // Posts only
          ];

    return Column(
      children: [
        TabBar(
          controller: controller.tabController,
          onTap: (value) {
            controller.userData.value?.checkIsBlocked(
              () {
                controller.onTabChanged(value);
                controller.pageController.animateToPage(
                  value,
                  duration:
                      const Duration(milliseconds: 300),
                  curve: Curves.linear,
                );
              },
            );
          },
          isScrollable: false,
          indicatorColor: Theme.of(context).brightness ==
                  Brightness.dark
              ? Colors.white
              : Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2.0,
          //  indicatorColor: Colors.transparent,
          tabs: List.generate(
            icons.length,
            (index) {
              return Obx(() {
                final color = controller
                            .selectedTabIndex.value ==
                        index
                    ? const Color.fromRGBO(55, 224, 4, 1)
                    : Colors.green;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0),
                  child: Image.asset(icons[index],
                      height: 40, width: 30, color: color),
                );
              });
            },
          ),
        ),
        Container(
            height: .5,
            color: Theme.of(context).brightness ==
                    Brightness.light
                ? whitePure(context)
                : blackPure(context)),
      ],
    );
  }
}

// original code

// class ProfileTabs extends StatelessWidget {
//   final ProfileScreenController controller;

//   const ProfileTabs({super.key, required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Obx(
//           () => Stack(
//             children: [
//               Container(height: .5, color: textLightGrey(context)),
//               AnimatedAlign(
//                 alignment: controller.selectedTabIndex.value == 1
//                     ? AlignmentDirectional.centerEnd
//                     : AlignmentDirectional.centerStart,
//                 duration: const Duration(milliseconds: 300),
//                 child: Container(
//                   height: 1,
//                   width: Get.width / 2 - 80,
//                   color: themeAccentSolid(context),
//                   margin: const EdgeInsets.symmetric(horizontal: 40),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         TabBar(
//             onTap: (value) {
//               controller.userData.value?.checkIsBlocked(() {
//                 controller.onTabChanged(value);
//               controller.pageController.animateToPage(value,
//                   duration: const Duration(milliseconds: 300), curve: Curves.linear);
//               });
//             },
//             indicatorColor: Colors.transparent,
//             tabs: List.generate(2, (index) {
//               final icon = index == 0 ? AssetRes.icReel : AssetRes.icPost;
//               return Obx(() {
//                 final color = controller.selectedTabIndex.value == index
//                     ? themeAccentSolid(context)
//                     : disableGrey(context);
//                 return Image.asset(icon, height: 50, width: 35, color: color);
//               });
//             })),
//         Container(height: .5, color: textLightGrey(context)),
//       ],
//     );
//   }
// }
