import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/gradient_text.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_background_blur_image.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveStreamSummary extends StatelessWidget {
  final LivestreamUserState? userState;
  final int viewers;
  final bool isHost;
  final List<LivestreamUserState> mostWatchedUsers;
  final VoidCallback? onGoHomeTap;

  const LiveStreamSummary(
      {super.key,
      this.userState,
      required this.isHost,
      required this.viewers,
      this.mostWatchedUsers = const [],
      this.onGoHomeTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        //  const LiveStreamBlurBackgroundImage(),
        SafeArea(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  CustomImage(
                      size: const Size(137, 137),
                      image: userState?.user?.profile
                          ?.addBaseURL(),
                      fullName: userState?.user?.fullname,
                      strokeColor: whitePure(context),
                      strokeWidth: 6),
                  const SizedBox(height: 11),
                  FullNameWithBlueTick(
                    username: userState?.user?.username,
                    fontSize: 14,
                    fontColor: ColorRes.green1,
                    isVerify: userState?.user?.isVerify,
                    iconSize: 18,
                  ),
                  Text(userState?.user?.fullname ?? '',
                      style:
                          TextStyleCustom.outFitRegular400(
                              fontSize: 16,
                              color: ColorRes.green1)),
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 30.0, bottom: 5),
                    child: Text(
                      isHost
                          ? LKey.streamEnded.tr
                          : LKey.yourStreamEnded.tr,
                      style: TextStyleCustom
                          .unboundedRegular400(
                              fontSize: 20,
                              color: ColorRes.green1),
                    ),
                  ),
                  Text(
                    LKey.belowIsTheSummaryOfYourStream.tr,
                    style: TextStyleCustom.outFitThin100(
                        fontSize: 17,
                        color: ColorRes.green1),
                  ),
                ],
              ),
              Column(
                children: [
                  BuildTextAndValueTiles(
                    title: LKey.streamedFor.tr,
                    value: (userState?.joinStreamTime ??
                            DateTime.now()
                                .millisecondsSinceEpoch)
                        .elapsedTimeFromEpoch,
                  ),
                  BuildTextAndValueTiles(
                      title: LKey.viewers.tr,
                      value:
                          '${(viewers - 1).clamp(0, viewers)}'),
                  BuildTextAndValueTiles(
                    title: LKey.followersGained.tr,
                    value:
                        '${userState?.followersGained.length ?? 0}',
                  ),
                  BuildTextAndValueTiles(
                    title: LKey.totalCoinsCollected.tr,
                    value:
                        userState?.totalCoin.toString() ??
                            '0',
                    widget: Column(
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          '${LKey.fromBattle.tr} : ${userState?.totalBattleCoin ?? 0} + ${LKey.live.tr} : ${userState?.liveCoin ?? 0}',
                          style:
                              TextStyleCustom.outFitThin100(
                                  color: ColorRes.green1),
                        ),
                      ],
                    ),
                  ),
                  if (isHost && mostWatchedUsers.isNotEmpty)
                    MostWatchedSection(users: mostWatchedUsers),
                ],
              ),
              InkWell(
                onTap: isHost ? onGoHomeTap : Get.back,
                child: Container(
                  height: 57,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 20),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                      shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                              cornerRadius: 10,
                              cornerSmoothing: 1),
                          side: BorderSide.none),
                      color: ColorRes.green1),
                  child: GradientText(
                    isHost
                        ? LKey.goHome.tr
                        : LKey.getBack.tr,
                    gradient: StyleRes.themeGradient,
                    style:
                        TextStyleCustom.unboundedMedium500(
                            fontSize: 17),
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}

class MostWatchedSection extends StatelessWidget {
  final List<LivestreamUserState> users;

  const MostWatchedSection({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              LKey.mostWatchTime.tr,
              style: TextStyleCustom.outFitMedium500(
                  color: ColorRes.green1, fontSize: 16),
            ),
          ),
          for (final state in users)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  CustomImage(
                    size: const Size(36, 36),
                    image: state.user?.profile?.addBaseURL(),
                    fullName: state.user?.fullname,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FullNameWithBlueTick(
                      username: state.user?.username,
                      fontColor: ColorRes.green1,
                      isVerify: state.user?.isVerify,
                      fontSize: 13,
                      iconSize: 16,
                    ),
                  ),
                  _FollowButton(userId: state.userId),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  final int userId;

  const _FollowButton({required this.userId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = false;

  Future<void> _onTap() async {
    if (_isFollowing || _isLoading) return;
    setState(() => _isLoading = true);
    final response =
        await UserService.instance.followUser(userId: widget.userId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.status == true) _isFollowing = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onTap,
      child: Container(
        height: 30,
        constraints: const BoxConstraints(minWidth: 90),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: _isFollowing
              ? Colors.transparent
              : ColorRes.green1,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
                cornerRadius: 8, cornerSmoothing: 1),
            side: _isFollowing
                ? const BorderSide(color: ColorRes.green1)
                : BorderSide.none,
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ColorRes.green1),
              )
            : Text(
                (_isFollowing ? LKey.following : LKey.follow).tr,
                style: TextStyleCustom.outFitMedium500(
                    color: _isFollowing
                        ? ColorRes.green1
                        : Colors.black,
                    fontSize: 13),
              ),
      ),
    );
  }
}

class BuildTextAndValueTiles extends StatelessWidget {
  final Widget? widget;
  final String title;
  final String value;

  const BuildTextAndValueTiles(
      {super.key,
      this.widget,
      required this.title,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: .5),
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: 18),
      color: whitePure(context).withValues(alpha: .1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyleCustom.outFitLight300(
                    color: ColorRes.green1, fontSize: 16),
              ),
              Text(
                value,
                style: TextStyleCustom.outFitMedium500(
                    color: ColorRes.green1, fontSize: 18),
              ),
            ],
          ),
          if (widget != null) widget!
        ],
      ),
    );
  }
}
