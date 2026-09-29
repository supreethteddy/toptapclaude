import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/follow_controller.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/gradient_border.dart';
import 'package:shortzz/common/widget/gradient_text.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/widget/live_stream_user_info_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/contributor_top_badges.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/fan_club_widgets.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/gift_goals_panel.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_poll_widgets.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_goal_progress_widget.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveStreamAudienceTopView extends StatelessWidget {
  final bool isAudience;
  final LivestreamScreenController controller;

  const LiveStreamAudienceTopView({
    super.key,
    this.isAudience = false,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      minimum: EdgeInsets.only(top: AppBar().preferredSize.height * 0.7),
      child: Obx(() {
        bool isVisible = controller.isViewVisible.value;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: isVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  // Live Goal Progress Widget for audience
                  LiveGoalProgressWidget(controller: controller),
                  PinnedGiftGoalChip(controller: controller),
                  LivePollBanner(controller: controller),
                  FanClubBanner(controller: controller),
                  _BuildTopView(controller: controller),
                  _BuildCenterView(controller: controller),
                  _BuildRankingRow(controller: controller),
                  _BuildBottomView(controller: controller),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BuildTopView extends StatelessWidget {
  final LivestreamScreenController controller;

  const _BuildTopView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Report (Figma "Live1": moved to top-left).
        InkWell(
          onTap: () {
            HapticManager.shared.light();
            controller.reportUser(controller.liveData.value.hostId);
          },
          child: Image.asset(
            AssetRes.icReport,
            color: whitePure(context).withValues(alpha: 0.5),
            width: 28,
            height: 28,
          ),
        ),
        // Top-3 contributor badges for THIS LIVE session (Figma "Live1"),
        // next to the viewer-count / close controls. Tap opens the full
        // Contributor Ranking sheet.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ContributorTopBadges(controller: controller),
            ),
          ),
        ),
        // Close (Figma "Live1": moved to top-right, red-tinted).
        Obx(() {
          Livestream stream = controller.liveData.value;
          bool isBattleRunning = stream.battleType != BattleType.initiate;
          bool isAudience =
              stream.coHostIds?.contains(controller.myUserId) == false;

          if (isBattleRunning && !isAudience) return const SizedBox();
          return InkWell(
            onTap: controller.onCloseAudienceBtn,
            child: Container(
              height: 25,
              width: 25,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ColorRes.likeRed,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Image.asset(
                AssetRes.icClose1,
                color: ColorRes.likeRed,
                width: 18,
                height: 18,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _BuildCenterView extends StatelessWidget {
  final LivestreamScreenController controller;

  const _BuildCenterView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Livestream stream = controller.liveData.value;
      AppUser? hostUser = controller.firestoreController.users.firstWhereOrNull(
        (element) => element.userId == stream.hostId,
      );
      return Row(
        spacing: 10,
        children: <Widget>[
          InkWell(
            onTap: () {
              Get.bottomSheet(
                LiveStreamUserInfoSheet(
                  isAudience: true,
                  liveUser: hostUser,
                  controller: controller,
                ),
                isScrollControlled: true,
              );
            },
            child: GradientBorder(
              strokeWidth: 2,
              gradient: StyleRes.themeGradient,
              radius: 30,
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: CustomImage(
                  size: const Size(40, 40),
                  image: hostUser?.profile?.addBaseURL(),
                  fit: BoxFit.cover,
                  fullName: hostUser?.fullname,
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FullNameWithBlueTick(
                        username: hostUser?.username,
                        fontSize: 13,
                        iconSize: 18,
                        fontColor: whitePure(context),
                        isVerify: hostUser?.isVerify,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // "X likes" (Figma "Live1"): same data source/formatting
                    // as the likes pill in LiveStreamBottomView.
                    Text(
                      '${(stream.likeCount ?? 0).numberFormat} ${LKey.likes.tr}',
                      style: TextStyleCustom.outFitRegular400(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _HostFollowPill(
                      hostUserId: stream.hostId,
                      controller: controller,
                    ),
                  ],
                ),
                Row(
                  children: [
                    FittedBox(
                      child: Container(
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: ShapeDecoration(
                          color: whitePure(context).withValues(alpha: 1),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(cornerRadius: 5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: GradientText(
                          LKey.host.tr.toUpperCase(),
                          gradient: StyleRes.themeGradient,
                          style: TextStyleCustom.unboundedBold700(fontSize: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        stream.description ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyleCustom.outFitRegular400(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Obx(() {
            Livestream liveData = controller.liveData.value;
            bool isBattleOn = liveData.type == LivestreamType.battle;
            bool isCoHost = (stream.coHostIds ?? []).contains(
              controller.myUserId,
            );
            int count = liveData.watchingCount ?? 0;
            int watchingCount = count >= 0 ? count : 0;
            return Row(
              spacing: 5,
              children: [
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: blackPure(context).withValues(alpha: .1),
                    border: Border.all(
                      color: whitePure(context).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Figma "Live1": person icon instead of an eye for the
                      // viewer count pill.
                      Image.asset(AssetRes.icAudience, height: 20, width: 20),
                      const SizedBox(width: 4),
                      Text(
                        watchingCount.numberFormat,
                        style: TextStyleCustom.outFitMedium500(
                          color: whitePure(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isBattleOn && liveData.isRestrictToJoin == 0 && !isCoHost)
                  LiveStreamCircleBorderButton(
                    image: AssetRes.icVideoRequest,
                    margin: EdgeInsets.zero,
                    iconColor: whitePure(context),
                    onTap: () => controller.onVideoRequestSend(liveData),
                  ),
                if (!isBattleOn)
                  LiveStreamCircleBorderButton(
                    image: AssetRes.icAudience,
                    margin: EdgeInsets.zero,
                    iconColor: whitePure(context),
                    onTap: controller.openAudienceSheet,
                  ),
              ],
            );
          }),
        ],
      );
    });
  }
}

/// Daily + hourly ranking chips, below the host info row (Figma "Live1").
/// Reuses the same [LiveRankChip]/[HourlyRankChip] widgets the host toolbar
/// already uses, so tapping either opens the matching ranking sheet.
class _BuildRankingRow extends StatelessWidget {
  final LivestreamScreenController controller;

  const _BuildRankingRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LiveRankChip(controller: controller),
          const SizedBox(width: 6),
          HourlyRankChip(controller: controller),
        ],
      ),
    );
  }
}

class _BuildBottomView extends StatelessWidget {
  final LivestreamScreenController controller;

  const _BuildBottomView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Livestream data = controller.liveData.value;
      bool isBattleView = data.type == LivestreamType.battle;
      StreamView? hostView = controller.streamViews.firstWhereOrNull(
        (element) => element.streamId == '${data.hostId}',
      );
      if (isBattleView) {
        return const SizedBox();
      }
      bool isDummyLive = data.isDummyLive == 1;
      return Container(
        width: 40,
        alignment: Alignment.center,
        child: MuteUnMuteButton(
          isMute: isDummyLive
              ? controller.isPlayerMute
              : (hostView?.isMuted ?? false).obs,
          onTap: () => isDummyLive
              ? controller.togglePlayerAudioToggle()
              : controller.toggleStreamAudio(data.hostId),
        ),
      );
    });
  }
}

/// Compact "Follow"/"Following" pill next to the host name (Figma "Live1").
///
/// Reuses the same follow/unfollow data + logic as
/// [LiveStreamUserInfoSheet] (`UserService.fetchUserDetails` for the
/// follow state, then [FollowController.followUnFollowUser] to toggle it),
/// scoped down to just the button instead of the whole sheet. Registers the
/// [FollowController] under the same `userId` tag the sheet uses, so both
/// stay in sync if the sheet is also open.
class _HostFollowPill extends StatefulWidget {
  final int? hostUserId;
  final LivestreamScreenController controller;

  const _HostFollowPill({required this.hostUserId, required this.controller});

  @override
  State<_HostFollowPill> createState() => _HostFollowPillState();
}

class _HostFollowPillState extends State<_HostFollowPill> {
  final Rx<User?> user = Rx(null);
  final RxBool isLoading = true.obs;
  final RxBool isFollowUnFollowInProcess = false.obs;

  @override
  void initState() {
    super.initState();
    _fetchHostProfile();
  }

  Future<void> _fetchHostProfile() async {
    if (widget.hostUserId == null ||
        widget.hostUserId == SessionManager.instance.getUserID()) {
      isLoading.value = false;
      return;
    }
    user.value = await UserService.instance.fetchUserDetails(
      userId: widget.hostUserId,
    );
    isLoading.value = false;
  }

  Future<void> _followUnFollowHost() async {
    int userId = user.value?.id ?? -1;
    if (userId == -1 || isFollowUnFollowInProcess.value) return;
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

    User? updatedUser = await followController.followUnFollowUser();
    final isFollowing = updatedUser?.isFollowing;
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
      val?.isFollowing = updatedUser?.isFollowing;
      val?.followerCount = updatedUser?.followerCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The host shouldn't see a follow button for themselves.
    if (widget.hostUserId == null ||
        widget.hostUserId == SessionManager.instance.getUserID()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      if (isLoading.value) return const SizedBox.shrink();
      final isFollowing = user.value?.isFollowing ?? false;
      return GestureDetector(
        onTap: isFollowUnFollowInProcess.value ? null : _followUnFollowHost,
        child: Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: isFollowing
                ? whitePure(context).withValues(alpha: .15)
                : blueFollow(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: whitePure(context).withValues(alpha: .3),
            ),
          ),
          alignment: Alignment.center,
          child: isFollowUnFollowInProcess.value
              ? SizedBox(
                  height: 10,
                  width: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(whitePure(context)),
                  ),
                )
              : Text(
                  isFollowing ? LKey.following.tr : LKey.follow.tr,
                  style: TextStyleCustom.outFitMedium500(
                    color: whitePure(context),
                    fontSize: 10,
                  ),
                ),
        ),
      );
    });
  }
}
