import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/navigation/navigate_with_controller.dart';
import 'package:toptap/common/widget/custom_back_button.dart';
import 'package:toptap/common/widget/custom_divider.dart';
import 'package:toptap/common/widget/custom_image.dart';
import 'package:toptap/common/widget/custom_tab_switcher.dart';
import 'package:toptap/common/widget/full_name_with_blue_tick.dart';
import 'package:toptap/common/widget/load_more_widget.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/common/widget/no_data_widget.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/follow_following_screen/follow_following_screen_controller.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

enum FollowFollowingType { follower, following }

class FollowFollowingScreen extends StatelessWidget {
  final FollowFollowingType type;
  final User? user;

  const FollowFollowingScreen(
      {super.key, required this.type, this.user});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
        FollowFollowingScreenController(
            type, user, context),
        tag: '${user?.id}');
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration:
                BoxDecoration(color: bgLightGrey(context)),
            padding:
                const EdgeInsets.symmetric(horizontal: 12),
            child: SafeArea(
              bottom: false,
              minimum: EdgeInsets.only(
                  top: AppBar().preferredSize.height),
              child: Column(
                children: [
                  Row(
                    children: [
                      CustomBackButton(
                          onTap: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                              return;
                            }
                            Get.back();
                          },
                          width: 35,
                          height: 18,
                          alignment: AlignmentDirectional
                              .centerStart),
                      CustomImage(
                        size: const Size(48, 48),
                        fullName: user?.fullname,
                        image: user?.profilePhoto
                            ?.addBaseURL(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            FullNameWithBlueTick(
                                username:
                                    user?.username ?? '',
                                fontSize: 13),
                            Text(user?.fullname ?? '',
                                style:
                                    TextStyleCustom
                                        .outFitLight300(
                                            color:
                                                textLightGrey(
                                                    context),
                                            fontSize: 15))
                          ],
                        ),
                      )
                    ],
                  ),
                  Obx(
                    () => CustomTabSwitcher(
                      items: [
                        '${controller.followerCount} ${LKey.followers.tr}',
                        '${controller.followingCount} ${LKey.following.tr}'
                      ],
                      selectedIndex:
                          controller.selectedTabIndex,
                      onTap: controller.onChangeTab,
                    ),
                  )
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final isFollowersEmpty =
                  controller.followers.isEmpty;
              final isFollowingsEmpty =
                  controller.followings.isEmpty;
              final showFollowersLoader =
                  controller.isFollowers.value &&
                      isFollowersEmpty;
              final showFollowingsLoader =
                  controller.isFollowings.value &&
                      isFollowingsEmpty;
              final showFollowersNoData =
                  !controller.isFollowers.value &&
                      isFollowersEmpty;
              final showFollowingsNoData =
                  !controller.isFollowings.value &&
                      isFollowingsEmpty;

              return PageView(
                controller: controller.pageController,
                onPageChanged: (value) => controller
                    .selectedTabIndex.value = value,
                children: [
                  // Followers Page
                  _buildUserList(
                    showLoader: showFollowersLoader,
                    showNoData: showFollowersNoData,
                    noDataTitle: null,
                    noDataDescription: null,
                    users: controller.followers,
                    userExtractor: (item) => item.fromUser,
                    onItemTap: controller.onFollowUnFollow,
                    loadMore: controller.fetchFollowers,
                    isFollowersTab: true,
                  ),

                  // Followings Page
                  _buildUserList(
                    showLoader: showFollowingsLoader,
                    showNoData: showFollowingsNoData,
                    noDataTitle: user?.showMyFollowing == 1
                        ? LKey.nothingToShowHere.tr
                        : null,
                    noDataDescription:
                        user?.showMyFollowing == 1
                            ? LKey.userHidFollowings.tr
                            : null,
                    users: controller.followings,
                    userExtractor: (item) => item.toUser,
                    onItemTap: controller.onFollowUnFollow,
                    loadMore: controller.fetchFollowings,
                    isFollowersTab: false,
                  ),
                ],
              );
            }),
          )
        ],
      ),
    );
  }

  // Helper Widget
  Widget _buildUserList({
    required bool showLoader,
    required bool showNoData,
    required String? noDataTitle,
    required String? noDataDescription,
    required List<dynamic> users,
    required User? Function(dynamic) userExtractor,
    required Function(dynamic) onItemTap,
    required Future Function()? loadMore,
    required bool isFollowersTab,
  }) {
    if (showLoader) return const LoaderWidget();

    return NoDataView(
      showShow: showNoData,
      title: noDataTitle,
      description: noDataDescription,
      child: ListView.builder(
        itemCount: users.length,
        padding: const EdgeInsets.only(top: 10),
        itemBuilder: (context, index) {
          final item = users[index];
          final user = userExtractor(item);
          final isFollow = user?.isFollowing == null
              ? true
              : user?.isFollowing ?? false;

          return UserProfileTile(
            actionName: ActionName.follow,
            onTap: () => onItemTap(item),
            isFollowOrIsBlock: isFollow,
            user: user,
            loadMore:
                index == users.length - 1 ? loadMore : null,
            isFollowersTab: isFollowersTab,
          );
        },
      ),
    );
  }
}

enum ActionName { follow, block }

class UserProfileTile extends StatelessWidget {
  final ActionName actionName;
  final bool isFollowOrIsBlock;
  final VoidCallback onTap;
  final User? user;
  final Future<void> Function()? loadMore;
  final bool isFollowersTab;

  const UserProfileTile(
      {super.key,
      required this.actionName,
      required this.isFollowOrIsBlock,
      required this.onTap,
      this.user,
      this.loadMore,
      required this.isFollowersTab});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        Theme.of(context).brightness == Brightness.dark;
    final Color actionButtonBg = isFollowOrIsBlock
        ? (isDarkMode
            ? const Color(0xFF1F1F1F)
            : whitePure(context))
        : blueFollow(context);
    final Color actionButtonText = isFollowOrIsBlock
        ? (isDarkMode
            ? whitePure(context)
            : textLightGrey(context))
        : whitePure(context);
    final BorderSide actionButtonBorder = isFollowOrIsBlock
        ? BorderSide(
            color: isDarkMode
                ? const Color(0xFF3A3A3A)
                : bgGrey(context),
          )
        : BorderSide.none;

    return LoadMoreWidget(
      loadMore: loadMore ?? () async {},
      child: Padding(
        padding: const EdgeInsets.only(
            left: 10.0, right: 10, bottom: 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      NavigationService.shared
                          .openProfileScreen(user);
                    },
                    child: Row(
                      children: [
                        CustomImage(
                            size: const Size(40, 40),
                            fullName: user?.fullname,
                            image: user?.profilePhoto
                                ?.addBaseURL()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              FullNameWithBlueTick(
                                username:
                                    user?.username ?? '',
                                isVerify: user?.isVerify,
                                fontSize: 13,
                                iconSize: 14,
                              ),
                              Text(
                                user?.fullname ?? '',
                                style: TextStyleCustom
                                    .outFitLight300(
                                        color:
                                            textLightGrey(
                                                context)),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (user?.id !=
                    SessionManager.instance.getUserID())
                  TextButtonCustom(
                      onTap: onTap,
                      title: actionName == ActionName.follow
                          ? (isFollowOrIsBlock
                              ? LKey.unFollow.tr
                              : _getFollowButtonText(user))
                          : (isFollowOrIsBlock
                              ? LKey.unBlock.tr
                              : LKey.block.tr),
                      btnWidth: 100,
                      fontSize: 15,
                      horizontalMargin: 0,
                      btnHeight: 30,
                      titleColor: actionButtonText,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0),
                      radius: 8,
                      backgroundColor: actionButtonBg,
                      borderSide: actionButtonBorder)
              ],
            ),
            const SizedBox(height: 10),
            const CustomDivider()
          ],
        ),
      ),
    );
  }

  String _getFollowButtonText(User? user) {
    if (user == null) return LKey.follow.tr;

    // In followers tab: if they follow me but I don't follow them back, show "Follow Back"
    // In following tab: just show "Follow" for non-following users
    if (isFollowersTab && !(user.isFollowing ?? false)) {
      // This person follows me (because they're in followers list)
      // but I don't follow them back, so show "Follow Back"
      return LKey.followBack.tr;
    }

    return LKey.follow.tr;
  }
}
