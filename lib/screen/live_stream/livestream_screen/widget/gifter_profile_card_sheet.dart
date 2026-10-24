import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/follow_controller.dart';
import 'package:shortzz/common/controller/live_status_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/widget/profile_user_header.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Profile card for a gifter tapped from a battle side's contributors list
/// (BattleContributorsSheet) -- modeled on LiveStreamUserInfoSheet, but that
/// sheet assumes its subject is on stage in *this* room (its non-audience
/// branch does controller.liveUsersStates.firstWhere(...), which throws for
/// a plain gifter who was never on stage), so this is a trimmed, room-
/// independent variant: just avatar/stats/bio/Follow, plus a Watch LIVE
/// button (via LiveStatusController) when the subject happens to be
/// hosting their own LIVE elsewhere -- a concept LiveStreamUserInfoSheet
/// doesn't have at all.
class GifterProfileCardSheet extends StatefulWidget {
  final int userId;
  final LivestreamScreenController controller;

  const GifterProfileCardSheet({
    super.key,
    required this.userId,
    required this.controller,
  });

  @override
  State<GifterProfileCardSheet> createState() =>
      _GifterProfileCardSheetState();
}

class _GifterProfileCardSheetState extends State<GifterProfileCardSheet> {
  Rx<User?> user = Rx(null);
  RxBool isLoading = true.obs;
  RxBool isFollowUnFollowInProcess = false.obs;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    isLoading.value = true;
    user.value =
        await UserService.instance.fetchUserDetails(userId: widget.userId);
    isLoading.value = false;
  }

  Future<void> _followUnFollowUser() async {
    final userId = user.value?.id ?? -1;
    if (userId == -1 || isFollowUnFollowInProcess.value) return;
    isFollowUnFollowInProcess.value = true;
    FollowController followController;
    if (Get.isRegistered<FollowController>(tag: userId.toString())) {
      followController = Get.find<FollowController>(tag: userId.toString());
      followController.updateUser(user.value);
    } else {
      followController =
          Get.put(FollowController(user), tag: userId.toString());
    }
    final updated = await followController.followUnFollowUser();
    isFollowUnFollowInProcess.value = false;
    user.update((val) {
      val?.isFollowing = updated?.isFollowing;
      val?.followerCount = updated?.followerCount;
    });
  }

  String _followButtonText(User? user) {
    if (user == null) return LKey.follow.tr;
    // They already follow me but I don't follow them back yet.
    if ((user.followStatus == 2 || user.followStatus == 3) &&
        !(user.isFollowing ?? false)) {
      return LKey.followBack.tr;
    }
    return LKey.follow.tr;
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
              final user = this.user.value;
              final isFollow = user?.isFollowing ?? false;
              final isSelf =
                  widget.userId == SessionManager.instance.getUserID();
              // Watch LIVE only makes sense when this contributor is
              // actually hosting their own LIVE right now -- LiveStatusController
              // is the app's single source of truth for that (same one
              // LiveRingAvatar/chat_top_profile_view already use).
              final isLive = LiveStatusController.to.isLive(widget.userId);
              final statItems = [
                StatItem(
                    value: user?.totalPostLikesCount ?? 0,
                    label: LKey.likes.tr),
                StatItem(
                    value: user?.followerCount ?? 0, label: LKey.followers.tr),
                StatItem(
                    value: user?.followingCount ?? 0,
                    label: LKey.following.tr),
              ];

              return isLoading.value
                  ? const LoaderWidget()
                  : Stack(
                      alignment: AlignmentDirectional.topEnd,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 30.0),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 25.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: statItems
                                      .map((item) => Expanded(
                                            child: StatColumn(
                                              value: item.value,
                                              label: item.label,
                                              valueStyle: TextStyleCustom
                                                  .unboundedSemiBold600(
                                                color: textDarkGrey(context),
                                                fontSize: 16,
                                              ),
                                              labelStyle: TextStyleCustom
                                                  .outFitRegular400(
                                                color: textLightGrey(context),
                                                fontSize: 15,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                              if (!isSelf)
                                Row(
                                  spacing: 10,
                                  children: [
                                    Expanded(
                                      child: isFollowUnFollowInProcess.value
                                          ? const LoaderWidget()
                                          : TextButtonCustom(
                                              onTap: _followUnFollowUser,
                                              title: isFollow
                                                  ? LKey.unFollow.tr
                                                  : _followButtonText(user),
                                              titleColor: isFollow
                                                  ? textLightGrey(context)
                                                  : whitePure(context),
                                              backgroundColor: isFollow
                                                  ? bgGrey(context)
                                                  : blueFollow(context),
                                              horizontalMargin: 0,
                                              borderSide: BorderSide(
                                                color: isFollow
                                                    ? whitePure(context)
                                                        .withValues(alpha: .3)
                                                    : whitePure(context),
                                                width: 1,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              if (!isSelf && isLive) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButtonCustom(
                                    onTap: () {
                                      Get.back();
                                      widget.controller
                                          .leaveLiveAndWatch(widget.userId);
                                    },
                                    title: 'Watch LIVE',
                                    titleColor: whitePure(context),
                                    backgroundColor: ColorRes.likeRed,
                                    horizontalMargin: 0,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
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
}
