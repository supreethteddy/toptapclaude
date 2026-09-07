import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/live_ring_avatar.dart';
import 'package:shortzz/common/widget/custom_popup_menu_button.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/gradient_border.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/edit_profile_screen/edit_profile_screen.dart';
import 'package:shortzz/screen/follow_following_screen/follow_following_screen.dart';
import 'package:shortzz/screen/level_screen/level_screen.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/widget/profile_preview_interactive_screen.dart';
import 'package:shortzz/screen/profile_screen/widget/user_link_sheet.dart';
import 'package:shortzz/screen/search_screen/search_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

// Below is the toptap modifed code

// ✅ Modified ProfileUserHeader.dart - Fulfills your requested header layout

class ProfileUserHeader extends StatelessWidget {
  final ProfileScreenController controller;

  const ProfileUserHeader(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      User? user = controller.userData.value;
      bool isUserNotFound = controller.isUserNotFound.value;

      return Padding(
        padding: const EdgeInsets.only(
            left: 15.0, right: 15.0, top: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            ProfileStatsRow(
              userNotFound: isUserNotFound,
              controller: controller,
              user: user,
              stats: [
                StatItem(
                    value: user?.followingCount ?? 0,
                    label: LKey.following.tr),
                StatItem(
                    value: user?.followerCount ?? 0,
                    label: LKey.followers.tr),
                StatItem(
                    value: user?.totalPostLikesCount ?? 0,
                    label: LKey.likes.tr),
              ],
              onTap: (value) {
                if (isUserNotFound) return;
                switch (value) {
                  case 0:
                    user?.checkIsBlocked(() => Get.to(() =>
                        FollowFollowingScreen(
                            type: FollowFollowingType
                                .following,
                            user: user)));
                    break;
                  case 1:
                    user?.checkIsBlocked(() => Get.to(() =>
                        FollowFollowingScreen(
                            type: FollowFollowingType
                                .follower,
                            user: user)));
                    break;
                }
              },
            ),
            const SizedBox(height: 12),
            if (!isUserNotFound)
              UserButtonView(
                  user: user, controller: controller),
            const SizedBox(height: 12),
            if (!isUserNotFound) UserBioView(user: user),
            const SizedBox(height: 12),
          ],
        ),
      );
    });
  }
}

class ProfileStatsRow extends StatelessWidget {
  final User? user;
  final List<StatItem> stats;
  final Function(int value) onTap;
  final ProfileScreenController controller;
  final bool userNotFound;

  const ProfileStatsRow({
    super.key,
    required this.user,
    required this.stats,
    required this.onTap,
    required this.controller,
    required this.userNotFound,
  });

  @override
  Widget build(BuildContext context) {
    bool isStoryAvailable =
        (user?.stories ?? []).isNotEmpty;
    GlobalKey previewKey = GlobalKey();
    bool isWatch = isStoryAvailable &&
        (user?.stories ?? [])
            .every((element) => element.isWatchedByMe());
    RxBool isHeroEnable = false.obs;

    return Column(
      children: [
        // Center Avatar
        Center(
          child: userNotFound
              ? Image.asset(
                  AssetRes.icUserPlaceholder,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                )
              : GestureDetector(
                  onTap: () => controller
                      .onStoryTap(isStoryAvailable),
                  onLongPressStart: (_) =>
                      isHeroEnable.value = true,
                  onLongPressEnd: (_) =>
                      isHeroEnable.value = false,
                  onLongPress: () {
                    user?.checkIsBlocked(() {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          opaque: false,
                          barrierColor: Colors.transparent,
                          transitionDuration:
                              const Duration(
                                  milliseconds: 300),
                          pageBuilder: (_, __, ___) =>
                              ProfilePreviewInteractiveScreen(
                                  user: user),
                        ),
                      );
                    });
                  },
                  child: Container(
                    key: previewKey,
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                            cornerRadius: 90),
                      ),
                      gradient: isStoryAvailable
                          ? (isWatch
                              ? StyleRes
                                  .disabledGreyGradient(
                                      opacity: .5)
                              : StyleRes.themeGradient)
                          : null,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: whitePure(context),
                      ),
                      child: Obx(
                        () => HeroMode(
                          enabled: isHeroEnable.value,
                          child: Hero(
                            tag: 'profile-${user?.id}',
                            child: LiveRingAvatar(
                              userId: user?.id,
                              ringWidth: 3,
                              ringGap: 4,
                              child: CustomImage(
                                size: isStoryAvailable
                                    ? const Size(70, 70)
                                    : const Size(80, 80),
                                image: user?.isBlock == true
                                    ? ''
                                    : user?.profilePhoto
                                        ?.addBaseURL(),
                                fullName: user?.fullname,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 8),

        // Username centered
        if (!userNotFound)
          Text(
            '@${user?.username ?? ""}',
            style: TextStyleCustom.outFitMedium500(
              fontSize: 16,
              color: textDarkGrey(context),
            ),
          ),

        const SizedBox(height: 12),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            stats.length,
            (index) => InkWell(
              onTap: () => onTap(index),
              child: Column(
                children: [
                  Text(
                    stats[index].value.toInt().numberFormat,
                    style:
                        TextStyleCustom.unboundedMedium500(
                      color: themeAccentSolid(context),
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    stats[index].label.capitalize ?? '',
                    style: TextStyleCustom.outFitLight300(
                      color: Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }
}

// Individual Stat Column Widget
class StatColumn extends StatelessWidget {
  final num value;
  final String label;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const StatColumn(
      {super.key,
      required this.value,
      required this.label,
      this.labelStyle,
      this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toInt().numberFormat,
          style: valueStyle ??
              TextStyleCustom.unboundedMedium500(
                color: textDarkGrey(context),
                fontSize: 15,
              ),
        ),
        Text(label.capitalize ?? '',
            style: labelStyle ??
                TextStyleCustom.outFitLight300(
                  color: textLightGrey(context),
                  fontSize: 15,
                )),
      ],
    );
  }
}

class UserNameView extends StatelessWidget {
  final User? user;

  const UserNameView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FullNameWithBlueTick(
          username: user?.username,
          style: TextStyleCustom.unboundedSemiBold600(
              color: textDarkGrey(context), fontSize: 17),
          isVerify: user?.isVerify,
          iconSize: 22,
          child: user?.getLevel.id == null
              ? const SizedBox()
              : GradientBorder(
                  onPressed: () {
                    Get.to(() => LevelScreen(
                        userLevels: user?.getLevel));
                  },
                  strokeWidth: 1.5,
                  radius: 30,
                  gradient: StyleRes.themeGradient,
                  child: Container(
                    height: 27,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15),
                    decoration: BoxDecoration(
                        borderRadius: SmoothBorderRadius(
                            cornerRadius: 30),
                        color: themeAccentSolid(context)
                            .withValues(alpha: .1)),
                    alignment: Alignment.center,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => StyleRes
                          .themeGradient
                          .createShader(Rect.fromLTWH(0, 0,
                              bounds.width, bounds.height)),
                      child: RichText(
                        text: TextSpan(
                          text: LKey.lvl.tr,
                          style: TextStyleCustom
                              .outFitLight300(fontSize: 15),
                          children: [
                            TextSpan(
                                text:
                                    ' ${user?.getLevel.level ?? 0}',
                                style: TextStyleCustom
                                    .outFitBold700(
                                        fontSize: 15))
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Text(user?.fullname ?? '',
            style: TextStyleCustom.outFitLight300(
                color: textLightGrey(context),
                fontSize: 16))
      ],
    );
  }
}

class UserLinkView extends StatelessWidget {
  final User? user;

  const UserLinkView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    List<Link> links = user?.links ?? [];
    if (links.isNotEmpty) {
      return InkWell(
        onTap: () {
          user?.checkIsBlocked(() {
            if (links.length > 1) {
              Get.bottomSheet(UserLinkSheet(links: links),
                  isScrollControlled: true,
                  barrierColor: blackPure(context)
                      .withValues(alpha: .7));
            } else {
              (links.first.url ?? '').lunchUrl;
            }
          });
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AssetRes.icLink,
                height: 20,
                width: 20,
                color: themeAccentSolid(context)),
            const SizedBox(width: 3),
            Expanded(
              child: Text(shortUrl,
                  style: TextStyleCustom.outFitRegular400(
                      fontSize: 15,
                      color: themeAccentSolid(context))),
            )
          ],
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  String get shortUrl {
    List<Link> links = user?.links ?? [];
    String firstLink = links.first.url ?? '';
    String andMore = '';
    if (firstLink.length >= 40) {
      int endCount = links.length > 1 ? 25 : 35;
      firstLink = '${firstLink.substring(0, endCount)}...';
    }
    if (links.length > 1) {
      andMore =
          ' & ${links.length - 1} ${LKey.more.tr.toLowerCase()}';
    }
    return '$firstLink$andMore';
  }
}

class UserBioView extends StatelessWidget {
  final User? user;

  const UserBioView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final bool isMe =
        user?.id == SessionManager.instance.getUserID();
    final String? bio = user?.bio?.trim();

    // Hide completely if not the owner and bio is empty
    if (!isMe && (bio == null || bio.isEmpty)) {
      return const SizedBox();
    }

    final bool isBioEmpty = bio == null || bio.isEmpty;
    final String displayText =
        isBioEmpty && isMe ? 'Tap to add bio' : bio!;

    return GestureDetector(
      onTap: isMe
          ? () {
              Get.to(() => EditProfileScreen(
                    onUpdateUser: (User? updatedUser) {
                      if (updatedUser != null) {
                        final controller = Get.find<
                            ProfileScreenController>();
                        controller
                            .onUpdateUser(updatedUser);
                      }
                    },
                  ));
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 8),
        child: Text(
          displayText,
          textAlign: TextAlign.center,
          style: TextStyleCustom.outFitLight300(
            color: ColorRes.likeRed,
            fontSize: 16,
          ).copyWith(
            fontStyle: isBioEmpty && isMe
                ? FontStyle.normal
                : FontStyle.normal,
            decoration: isMe
                ? TextDecoration.none
                : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class UserButtonView extends StatelessWidget {
  final User? user;
  final ProfileScreenController controller;

  const UserButtonView({
    super.key,
    required this.user,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMe =
        user?.id == SessionManager.instance.getUserID();
    final bool isBlock = (user?.isBlock == true && !isMe);
    final bool isMod =
        SessionManager.instance.isModerator.value == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, top: 10),
      child: Row(
        children: [
          Expanded(
            child: isBlock
                ? UnblockButton(
                    onTap: () =>
                        controller.toggleBlockUnblock(true),
                  )
                : RowButton(
                    controller: controller,
                    isMe: isMe,
                    user: user,
                  ),
          ),
          const SizedBox(width: 8),
          if (isMe)
            InkWell(
              onTap: () {
                // Navigate to SearchScreen with Users tab selected
                Get.to(() =>
                    const SearchScreen(initialTabIndex: 2));
              },
              child: Container(
                height: 45,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12),
                decoration: ShapeDecoration(
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: adaptiveBorderColor(context),
                      width: 1.5,
                    ),
                    borderRadius: SmoothBorderRadius(
                        cornerRadius: 10),
                  ),
                  color: adaptiveBackground(context),
                ),
                child: Image.asset(AssetRes.icaddfriend,
                    height: 21, width: 21),
              ),
            )
          else
            CustomPopupMenuButton(
              items: [
                MenuItem(
                  user?.isBlock == true
                      ? LKey.unBlock.tr
                      : LKey.block.tr,
                  () => controller.toggleBlockUnblock(
                      user?.isBlock ?? false),
                ),
                MenuItem(LKey.report.tr,
                    () => controller.reportUser(user)),
                if (isMod)
                  MenuItem(
                    user?.isFreez == 1
                        ? LKey.unFreeze.tr
                        : LKey.freeze.tr,
                    () => controller.freezeUnfreezeUser(
                        user?.isFreez == 1),
                  ),
              ],
              child: Container(
                height: 45,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12),
                decoration: ShapeDecoration(
                  shape: SmoothRectangleBorder(
                    side: BorderSide(
                      color: adaptiveBorderColor(context),
                      width: 1.5,
                    ),
                    borderRadius: SmoothBorderRadius(
                        cornerRadius: 10),
                  ),
                  color: adaptiveBackground(context),
                ),
                child: Image.asset(AssetRes.icMore,
                    height: 21, width: 21),
              ),
            ),
        ],
      ),
    );
  }
}

class NoUserFoundButton extends StatelessWidget {
  const NoUserFoundButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButtonCustom(
      onTap: () {},
      title: LKey.userNotFound.tr,
      btnHeight: 40,
      backgroundColor: bgMediumGrey(context),
      fontSize: 15,
      radius: 8,
      titleColor: textLightGrey(context),
      margin: const EdgeInsets.only(
          bottom: 10, left: 40, right: 40, top: 20),
    );
  }
}

class UnblockButton extends StatelessWidget {
  final VoidCallback onTap;

  const UnblockButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButtonCustom(
      onTap: onTap,
      title: LKey.unBlock.tr,
      fontSize: 16,
      backgroundColor: blueFollow(context),
      titleColor: whitePure(context),
      horizontalMargin: 0,
      btnHeight: 45,
    );
  }
}

class RowButton extends StatelessWidget {
  final bool isMe;
  final ProfileScreenController controller;
  final User? user;

  const RowButton({
    super.key,
    required this.isMe,
    required this.controller,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFollowing = user?.isFollowing == true;

    return Row(
      children: [
        Expanded(
          child:
              TextButtonCustomforuserprofileandfollowersprofile(
            borderSide: BorderSide(
              width: 2,
              //   color: adaptiveBorderColor(context),
            ),
            onTap: () {
              if (isMe) {
                Get.to(() => EditProfileScreen(
                      onUpdateUser: controller.onUpdateUser,
                    ));
              } else {
                controller.followUnFollowUser();
              }
            },
            title: isMe
                ? LKey.editprofile.tr
                : isFollowing
                    ? LKey.unFollow.tr
                    : _getFollowButtonText(user),
            fontSize: 16,
            backgroundColor: adaptiveBackground(context),
            titleColor: ColorRes.textlightGreenColor,
            horizontalMargin: 0,
            btnHeight: 45,
          ),
        ),
        const SizedBox(width: 8),
        if (isMe || user?.receiveMessage == 1)
          Expanded(
            child:
                TextButtonCustomforuserprofileandfollowersprofile(
              borderSide: const BorderSide(
                //  color: adaptiveBorderColor(context),
                width: 2,
              ),
              onTap: () => controller
                  .handlePublishOrMessageBtn(isMe),
              title: isMe
                  ? LKey.share.tr + " Profile"
                  : LKey.message.tr,
              fontSize: 16,
              // backgroundColor: ,
              //  titleColor: titleColor,
              horizontalMargin: 0,
              btnHeight: 45,
            ),
          ),
      ],
    );
  }

  String _getFollowButtonText(User? user) {
    if (user == null) return LKey.follow.tr;

    // If the user follows me (followStatus 2 or 3) but I'm not following them back
    if ((user.followStatus == 2 ||
            user.followStatus == 3) &&
        !(user.isFollowing ?? false)) {
      return LKey.followBack.tr;
    }

    return LKey.follow.tr;
  }
}

// Stat Item Model
class StatItem {
  final num value;
  final String label;

  StatItem({required this.value, required this.label});
}














// class UserButtonView extends StatelessWidget {
//   final User? user;
//   final ProfileScreenController controller;

//   const UserButtonView(
//       {super.key,
//       required this.user,
//       required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     User? user = controller.profileController.user;

//     bool isMe = user?.id?.toInt() ==
//         SessionManager.instance.getUserID();
//     bool isBlock = (user?.isBlock == true &&
//         user?.id != SessionManager.instance.getUserID());
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 20.0, top: 10),
//       child: Row(
//         children: [
//           Expanded(
//             child: isBlock
//                 ? UnblockButton(
//                     onTap: () =>
//                         controller.toggleBlockUnblock(true))
//                 : RowButton(
//                     controller: controller,
//                     isMe: isMe,
//                     user: user),
//           ),
//           const SizedBox(width: 8),
//           if (isMe)
//             InkWell(
//               onTap: () {
//                 BranchIoManager.instance.shareContent(
//                     type: ShareBranchType.user, user: user);
//               },
//               child: Container(
//                   height: 45,
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 12),
//                   decoration: ShapeDecoration(
//                     shape: SmoothRectangleBorder(
//                         borderRadius: SmoothBorderRadius(
//                             cornerRadius: 10,
//                             cornerSmoothing: 1)),
//                     color: bgGrey(context),
//                   ),
//                   child: Image.asset(
//                       isMe
//                           ? AssetRes.icShare1
//                           : AssetRes.icMore,
//                       height: 21,
//                       width: 21)),
//             )
//           else
//             Obx(
//               () => CustomPopupMenuButton(
//                   items: [
//                     MenuItem(
//                         user?.isBlock == true
//                             ? LKey.unBlock.tr
//                             : LKey.block.tr, () {
//                       controller.toggleBlockUnblock(
//                           user?.isBlock ?? false);
//                     }),
//                     MenuItem(LKey.report.tr,
//                         () => controller.reportUser(user)),
//                     if (SessionManager
//                             .instance.isModerator.value ==
//                         1)
//                       MenuItem(
//                           user?.isFreez == 1
//                               ? LKey.unFreeze.tr
//                               : LKey.freeze.tr,
//                           () =>
//                               controller.freezeUnfreezeUser(
//                                   user?.isFreez == 1))
//                   ],
//                   child: Container(
//                     height: 45,
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 12),
//                     decoration: ShapeDecoration(
//                       shape: SmoothRectangleBorder(
//                           borderRadius: SmoothBorderRadius(
//                               cornerRadius: 10,
//                               cornerSmoothing: 1)),
//                       color: bgGrey(context),
//                     ),
//                     child: Image.asset(AssetRes.icMore,
//                         height: 21, width: 21),
//                   )),
//             )
//         ],
//       ),
//     );
//   }
// }





// class RowButton extends StatelessWidget {
//   final bool isMe;
//   final ProfileScreenController controller;
//   final User? user;

//   const RowButton({
//     super.key,
//     required this.isMe,
//     required this.controller,
//     required this.user,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final bool isFollowing = user?.isFollowing == true;

//     return Row(
//       children: [
//         Expanded(
//           child: TextButtonCustom(
//             borderSide: BorderSide(
//               width: 2,
//               color: Theme.of(context).brightness ==
//                       Brightness.light
//                   ? Colors.grey
//                   : Colors.grey,
//             ),
//             onTap: () {
//               if (isMe) {
//                 Get.to(() => EditProfileScreen(
//                       onUpdateUser: controller.onUpdateUser,
//                     ));
//               } else {
//                 controller.followUnFollowUser();
//               }
//             },
//             title: isMe
//                 ? LKey.editprofile.tr
//                 : isFollowing
//                     ? LKey.unFollow.tr
//                     : LKey.follow.tr,
//             fontSize: 16,
//             backgroundColor: isMe
//                 ? Theme.of(context).brightness ==
//                         Brightness.light
//                     ? Colors.white
//                     : Colors.black
//                 : isFollowing
//                     ? Theme.of(context).brightness ==
//                             Brightness.light
//                         ? Colors.white
//                         : Colors.black
//                     : Theme.of(context).brightness ==
//                             Brightness.light
//                         ? Colors.white
//                         : Colors.black,
//             titleColor: isMe
//                 ? const Color.fromRGBO(55, 224, 4, 1)
//                 : isFollowing
//                     ? const Color.fromRGBO(55, 224, 4, 1)
//                     : const Color.fromRGBO(55, 224, 4, 1),
//             horizontalMargin: 0,
//             btnHeight: 45,
//           ),
//         ),
//         const SizedBox(width: 8),
//         if (isMe || user?.receiveMessage == 1)
//           Expanded(
//             child: TextButtonCustom(
//               borderSide: BorderSide(
//                 width: 2,
//                 color: Theme.of(context).brightness ==
//                         Brightness.light
//                     ? Colors.grey
//                     : Colors.grey,
//               ),
//               onTap: () => controller
//                   .handlePublishOrMessageBtn(isMe),
//               title:
//                   isMe ? LKey.publish.tr : LKey.message.tr,
//               fontSize: 16,
//               backgroundColor:
//                   Theme.of(context).brightness ==
//                           Brightness.light
//                       ? Colors.white
//                       : Colors.black,
//               titleColor:
//                   const Color.fromRGBO(55, 224, 4, 1),
//               horizontalMargin: 0,
//               btnHeight: 45,
//             ),
//           ),
//       ],
//     );
//   }
// }
// Uncomment the below code if you want to use the RowButton widget
// class RowButton extends StatelessWidget {
//   final bool isMe;
//   final ProfileScreenController controller;
//   final User? user;

//   const RowButton({
//     super.key,
//     required this.isMe,
//     required this.controller,
//     this.user,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(
//           child: TextButtonCustom(
//             onTap: () async {
//               if (isMe) {
//                 Get.to(() => EditProfileScreen(
//                     onUpdateUser: controller.onUpdateUser));
//               } else {
//                 controller.followUnFollowUser();
//               }
//             },
//             title: isMe
//                 ? LKey.editprofile.tr
//                 : (user?.isFollowing == true
//                     ? LKey.unFollow.tr
//                     : LKey.follow.tr),
//             fontSize: 16,
//             backgroundColor: isMe
//                 ? bgGrey(context)
//                 : (user?.isFollowing == true
//                     ? bgGrey(context)
//                     : blueFollow(context)),
//             titleColor: isMe
//                 ? textLightGrey(context)
//                 : (user?.isFollowing == true
//                     ? textLightGrey(context)
//                     : whitePure(context)),
//             horizontalMargin: 0,
//             btnHeight: 45,
//           ),
//         ),
//         const SizedBox(width: 8),
//         if (isMe || user?.receiveMessage == 1)
//           Expanded(
//             child: TextButtonCustom(
//               onTap: () => controller
//                   .handlePublishOrMessageBtn(isMe),
//               title:
//                   isMe ? LKey.publish.tr : LKey.message.tr,
//               fontSize: 16,
//               backgroundColor: bgGrey(context),
//               titleColor: textLightGrey(context),
//               horizontalMargin: 0,
//               btnHeight: 45,
//             ),
//           ),
//       ],
//     );
//   }
// }

// class RowButton extends StatelessWidget {
//   final bool isMe;
//   final ProfileScreenController controller;
//   final User? user;

//   const RowButton({
//     super.key,
//     required this.isMe,
//     required this.controller,
//     this.user,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(
//           child: TextButtonCustom(
//               onTap: () async {
//                 if (isMe) {
//                   Get.to(() => EditProfileScreen(
//                       onUpdateUser:
//                           controller.onUpdateUser));
//                 } else {
//                   controller.followUnFollowUser();
//                   // _followUnfollowUser();
//                 }
//               },
//               title: isMe
//                   ? LKey.editprofile.tr
//                   : (user?.isFollowing == true
//                       ? LKey.unFollow.tr
//                       : LKey.follow.tr),
//               fontSize: 16,
//               backgroundColor: isMe
//                   ? bgGrey(context)
//                   : (user?.isFollowing == true
//                       ? bgGrey(context)
//                       : blueFollow(context)),
//               titleColor: isMe
//                   ? textLightGrey(context)
//                   : (user?.isFollowing == true
//                       ? textLightGrey(context)
//                       : whitePure(context)),
//               horizontalMargin: 0,
//               btnHeight: 45),
//         ),
//         const SizedBox(width: 8),
//         if (isMe || user?.receiveMessage == 1)
//           Expanded(
//             child: TextButtonCustom(
//                 onTap: () => controller
//                     .handlePublishOrMessageBtn(isMe),
//                 title: isMe
//                     ? LKey.publish.tr
//                     : LKey.message.tr,
//                 fontSize: 16,
//                 backgroundColor: bgGrey(context),
//                 titleColor: textLightGrey(context),
//                 horizontalMargin: 0,
//                 btnHeight: 45),
//           ),
//       ],
//     );
//   }
// }



// class UserBioView extends StatelessWidget {
//   final User? user;

//   const UserBioView({super.key, required this.user});

//   @override
//   Widget build(BuildContext context) {
//     if ((user?.bio ?? '').isEmpty) {
//       return const SizedBox();
//     }
//     return Text(
//       user?.bio ?? '',
//       style: TextStyleCustom.outFitLight300(
//           color: textLightGrey(context), fontSize: 16),
//     );
//   }
// }
