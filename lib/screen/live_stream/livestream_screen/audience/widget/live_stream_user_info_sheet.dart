import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/controller/follow_controller.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/api/user_service.dart';
import 'package:toptap/common/service/navigation/navigate_with_controller.dart';
import 'package:toptap/common/widget/confirmation_dialog.dart';
import 'package:toptap/common/widget/custom_back_button.dart';
import 'package:toptap/common/widget/custom_divider.dart';
import 'package:toptap/common/widget/custom_image.dart';
import 'package:toptap/common/widget/full_name_with_blue_tick.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/livestream/app_user.dart';
import 'package:toptap/model/livestream/livestream_user_state.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart';
import 'package:toptap/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:toptap/screen/profile_screen/widget/profile_user_header.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/color_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class LiveStreamUserInfoSheet extends StatefulWidget {
  final bool isAudience;
  final AppUser? liveUser;
  final LivestreamScreenController controller;

  const LiveStreamUserInfoSheet({
    super.key,
    required this.isAudience,
    this.liveUser,
    required this.controller,
  });

  @override
  State<LiveStreamUserInfoSheet> createState() =>
      _LiveStreamUserInfoSheetState();
}

class _LiveStreamUserInfoSheetState extends State<LiveStreamUserInfoSheet> {
  Rx<User?> user = Rx(null);
  RxBool isLoading = true.obs;
  RxBool isFollowUnFollowInProcess = false.obs;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  _fetchUserProfile() async {
    isLoading.value = true;
    user.value = await UserService.instance.fetchUserDetails(
      userId: widget.liveUser?.userId,
    );
    isLoading.value = false;
  }

  Future<void> followUnFollowUser() async {
    int userId = user.value?.id ?? -1;
    if (isFollowUnFollowInProcess.value) return;
    final wasFollowing = user.value?.isFollowing ?? false;
    isFollowUnFollowInProcess.value = true;
    FollowController followController;
    if (Get.isRegistered<FollowController>(tag: userId.toString())) {
      followController = Get.find<FollowController>(tag: userId.toString());
      followController.updateUser(user.value);
    } else {
      followController = Get.put(
        FollowController(user),
        tag: userId.toString(),
      );
    }

    User? updateUser = await followController.followUnFollowUser();
    final isFollowing = updateUser?.isFollowing;
    widget.controller.updateUserStateToFirestore(userId, isFollow: isFollowing);
    if (isFollowing != null &&
        isFollowing != wasFollowing &&
        userId == widget.controller.liveData.value.hostId &&
        widget.controller.liveData.value.hasLiveGoal == true &&
        widget.controller.liveData.value.liveGoalType == 'followers') {
      widget.controller.incrementLiveGoalProgress(isFollowing ? 1 : -1);
    }
    isFollowUnFollowInProcess.value = false;
    user.update((val) {
      val?.isFollowing = updateUser?.isFollowing;
      val?.followerCount = updateUser?.followerCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: ShapeDecoration(
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 40, cornerSmoothing: 1),
              ),
            ),
            color: scaffoldBackgroundColor(context),
          ),
          child: SafeArea(
            top: false,
            child: Obx(() {
              User? user = this.user.value;
              bool isFollow = user?.isFollowing ?? false;
              List<StatItem> statItems = [
                StatItem(
                  value: user?.totalPostLikesCount ?? 0,
                  label: LKey.likes.tr,
                ),
                StatItem(
                  value: user?.followerCount ?? 0,
                  label: LKey.followers.tr,
                ),
                StatItem(
                  value: user?.followingCount ?? 0,
                  label: LKey.following.tr,
                ),
              ];

              return isLoading.value
                  ? const LoaderWidget()
                  : Stack(
                      alignment: AlignmentDirectional.topEnd,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30.0),
                          child: Column(
                            children: [
                              const CustomDivider(width: 100),
                              const SizedBox(height: 10),
                              CustomImage(
                                size: const Size(93, 93),
                                image: user?.profilePhoto?.addBaseURL(),
                                fullName: user?.fullname,
                              ),
                              const SizedBox(height: 10),
                              FullNameWithBlueTick(
                                username: user?.username,
                                isVerify: user?.isVerify,
                                fontSize: 14,
                                iconSize: 18,
                              ),
                              Text(
                                user?.fullname ?? '',
                                style: TextStyleCustom.outFitRegular400(
                                  fontSize: 16,
                                  color: textLightGrey(context),
                                ),
                              ),
                              if ((user?.bio ?? '').isNotEmpty)
                                const SizedBox(height: 18),
                              if ((user?.bio ?? '').isNotEmpty)
                                Text(
                                  user?.bio ?? '',
                                  style: TextStyleCustom.outFitLight300(
                                    fontSize: 15,
                                    color: textLightGrey(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 25.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: List.generate(statItems.length, (
                                    index,
                                  ) {
                                    StatItem item = statItems[index];
                                    return Expanded(
                                      child: StatColumn(
                                        value: item.value,
                                        label: item.label,
                                        valueStyle:
                                            TextStyleCustom.unboundedSemiBold600(
                                              color: textDarkGrey(context),
                                              fontSize: 16,
                                            ),
                                        labelStyle:
                                            TextStyleCustom.outFitRegular400(
                                              color: textLightGrey(context),
                                              fontSize: 15,
                                            ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              if (widget.liveUser?.userId !=
                                  SessionManager.instance.getUserID())
                                Row(
                                  spacing: 10,
                                  children: [
                                    if (widget.isAudience)
                                      Expanded(
                                        child: TextButtonCustom(
                                          onTap: () {
                                            Get.back();
                                            Get.bottomSheet(
                                              ConfirmationSheet(
                                                title: LKey.exitLiveStream.tr,
                                                description: LKey
                                                    .ifYouCheckThisProfileEtc
                                                    .tr,
                                                onTap: () {
                                                  Get.back();

                                                  NavigationService.shared
                                                      .openProfileScreen(user);
                                                },
                                              ),
                                            );
                                          },
                                          title: LKey.checkProfile.tr,
                                          titleColor: textLightGrey(context),
                                          backgroundColor: bgMediumGrey(
                                            context,
                                          ),
                                          horizontalMargin: 0,
                                          borderSide: BorderSide(
                                            color: whitePure(
                                              context,
                                            ).withValues(alpha: .3),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: isFollowUnFollowInProcess.value
                                          ? const LoaderWidget()
                                          : TextButtonCustom(
                                              onTap: followUnFollowUser,
                                              title: isFollow
                                                  ? LKey.unFollow.tr
                                                  : _getFollowButtonText(user),
                                              titleColor: isFollow
                                                  ? textLightGrey(context)
                                                  : whitePure(context),
                                              backgroundColor: isFollow
                                                  ? bgGrey(context)
                                                  : blueFollow(context),
                                              horizontalMargin: 0,
                                              borderSide: BorderSide(
                                                color: isFollow
                                                    ? whitePure(
                                                        context,
                                                      ).withValues(alpha: .3)
                                                    : whitePure(context),
                                                width: 1,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              if (!widget.isAudience)
                                Obx(() {
                                  LivestreamUserState? state = widget
                                      .controller
                                      .liveUsersStates
                                      .firstWhere((element) {
                                        return element.userId ==
                                            widget.liveUser?.userId;
                                      });

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    spacing: 8,
                                    children: [
                                      LiveStreamCircleBorderButton(
                                        image: state.isMuted
                                            ? AssetRes.icMicOff
                                            : AssetRes.icMicrophone,
                                        iconColor: textLightGrey(context),
                                        borderColor: bgGrey(context),
                                        size: const Size(40, 40),
                                        onTap: () => widget.controller
                                            .coHostAudioToggle(state),
                                      ),
                                      LiveStreamCircleBorderButton(
                                        image: state.isVideoOn
                                            ? AssetRes.icVideoCamera
                                            : AssetRes.icVideoOff,
                                        iconColor: textLightGrey(context),
                                        borderColor: bgGrey(context),
                                        size: const Size(40, 40),
                                        onTap: () => widget.controller
                                            .coHostVideoToggle(state),
                                      ),
                                      LiveStreamCircleBorderButton(
                                        image: AssetRes.icDelete1,
                                        iconColor: ColorRes.likeRed,
                                        borderColor: ColorRes.likeRed,
                                        size: const Size(40, 40),
                                        onTap: () {
                                          Get.back();
                                          widget.controller.coHostDelete(state);
                                        },
                                      ),
                                    ],
                                  );
                                }),
                            ],
                          ),
                        ),
                        const CustomBackButton(
                          image: AssetRes.icClose,
                          width: 23,
                          height: 23,
                          padding: EdgeInsets.all(10),
                        ),
                      ],
                    );
            }),
          ),
        ),
      ],
    );
  }

  String _getFollowButtonText(User? user) {
    if (user == null) return LKey.follow.tr;

    // If the user follows me (followStatus 2 or 3) but I'm not following them back
    if ((user.followStatus == 2 || user.followStatus == 3) &&
        !(user.isFollowing ?? false)) {
      return LKey.followBack.tr;
    }

    return LKey.follow.tr;
  }
}
