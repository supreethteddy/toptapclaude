import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:readmore/readmore.dart';
import 'package:shortzz/common/controller/follow_controller.dart';
import 'package:shortzz/common/controller/profile_controller.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/hashtag_screen/hashtag_screen.dart';
import 'package:shortzz/screen/location_screen/location_screen.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/font_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class UserInformation extends StatelessWidget {
  final ReelController controller;

  const UserInformation(
      {super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          UserInfoHeader(controller: controller),
          const SizedBox(height: 2),
          UserStats(controller: controller),
          UserLocation(controller: controller),
          UserDescription(controller: controller),
          UserMusicName(controller: controller),
        ],
      ),
    );
  }
}

class UserInfoHeader extends StatelessWidget {
  const UserInfoHeader(
      {required this.controller, super.key});

  final ReelController controller;

  @override
  Widget build(BuildContext context) {
    User? reelUser = controller.reelData.value.user;
    late ProfileController profileController;
    if (Get.isRegistered<ProfileController>(
        tag: '${reelUser?.id}')) {
      profileController = Get.find<ProfileController>(
          tag: '${reelUser?.id}');
    } else {
      profileController = Get.put(
          ProfileController(reelUser),
          tag: '${reelUser?.id}');
    }
    User? user = profileController.user;
    return Row(
      children: [
        InkWell(
          onTap: () => controller.onUserTap(user),
          child: FullNameWithBlueTick(
              username: user?.username,
              isVerify: user?.isVerify,
              fontColor: whitePure(context),
              fontSize: 14,
              iconSize: 18),
        ),
        FollowButton(controller: controller),
      ],
    );
  }
}

class FollowButton extends StatelessWidget {
  final ReelController controller;

  const FollowButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final followController = Get.put(
        FollowController(
            controller.reelData.value.user.obs),
        tag: '${controller.reelData.value.userId}');
    return Obx(() {
      bool isFollow =
          followController.user.value?.isFollowing ?? false;
      if (followController.user.value?.id ==
          SessionManager.instance.getUserID()) {
        return const SizedBox();
      }
      return AnimatedOpacity(
        opacity: isFollow ? 0 : 1,
        duration: const Duration(milliseconds: 10),
        child: InkWell(
          onTap: isFollow
              ? () {}
              : () async {
                  await followController
                      .followUnFollowUser();
                },
          child: Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                  borderRadius:
                      SmoothBorderRadius(cornerRadius: 30),
                  side: BorderSide(
                      color: whitePure(context)
                          .withValues(alpha: .3)),
                  borderAlign: BorderAlign.inside),
              color:
                  whitePure(context).withValues(alpha: .05),
            ),
            child: Text(
              _getFollowButtonText(
                  followController.user.value),
              style: TextStyleCustom.outFitRegular400(
                  fontSize: 13, color: whitePure(context)),
            ),
          ),
        ),
      );
    });
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

class UserStats extends StatelessWidget {
  const UserStats({super.key, required this.controller});

  final ReelController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Post? reel = controller.reelData.value;
      num views = reel.views ?? 0;
      return Row(
        children: [
          Text(
            reel.id == -1
                ? DateFormat('dd MMM yyyy')
                    .format(DateTime.now())
                : (reel.createdAt ?? '').formatDate,
            style: TextStyleCustom.outFitLight300(
                color: whitePure(context),
                opacity: .8,
                fontSize: 11),
          ),
          if (views > 0)
            Row(
              children: [
                Container(
                  height: 3,
                  width: 3,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 3),
                  decoration: BoxDecoration(
                      color: whitePure(context)
                          .withValues(alpha: .8),
                      shape: BoxShape.circle),
                ),
                Text(
                  '${reel.views ?? '0'} ${LKey.views.tr}',
                  style: TextStyleCustom.outFitLight300(
                      color: whitePure(context),
                      opacity: .8,
                      fontSize: 11),
                ),
              ],
            )
        ],
      );
    });
  }
}

class UserLocation extends StatelessWidget {
  final ReelController controller;

  const UserLocation({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    Post reel = controller.reelData.value;
    if (reel.placeTitle == null) {
      return const SizedBox();
    }

    return InkWell(
      onTap: () {
        double? latitude = reel.placeLat?.toDouble();
        double? longitude = reel.placeLon?.toDouble();
        LatLng latLng =
            LatLng(latitude ?? 0.0, longitude ?? 0.0);
        Get.to(
            () => LocationScreen(
                latLng: latLng,
                placeTitle: reel.placeTitle ?? ''),
            preventDuplicates: false);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              Image.asset(
                AssetRes.icLocationPin,
                width: 13,
                height: 13,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(reel.placeTitle ?? '',
                    style: TextStyleCustom.outFitLight300(
                      color: whitePure(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UserMusicName extends StatelessWidget {
  final ReelController controller;

  const UserMusicName({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final music = controller.reelData.value.music;
      if (music == null ||
          ((music.title ?? '').isEmpty &&
              (music.artist ?? '').isEmpty)) {
        return const SizedBox();
      }
      final label = [music.artist, music.title]
          .where((e) => (e ?? '').isNotEmpty)
          .join(' - ');
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AssetRes.icMusic,
                width: 13, height: 13, color: whitePure(context)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyleCustom.outFitLight300(
                    color: whitePure(context), fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class UserDescription extends StatefulWidget {
  const UserDescription(
      {super.key, required this.controller});

  final ReelController controller;

  @override
  State<UserDescription> createState() =>
      _UserDescriptionState();
}

class _UserDescriptionState extends State<UserDescription> {
  final RxBool isCollapsed = true.obs;
  late final ValueNotifier<bool> _collapsedNotifier;

  @override
  void initState() {
    super.initState();
    // Bridge GetX reactive to ValueNotifier for third-party package compatibility
    _collapsedNotifier = ValueNotifier(isCollapsed.value);

    // Keep them in sync
    isCollapsed.listen((value) {
      _collapsedNotifier.value = value;
    });

    _collapsedNotifier.addListener(() {
      isCollapsed.value = _collapsedNotifier.value;
    });
  }

  @override
  void dispose() {
    _collapsedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Post? reel = widget.controller.reelData.value;
    if (reel.description == null ||
        (reel.description ?? '').isEmpty) {
      return const SizedBox();
    }
    return InkWell(
      onTap: () {
        isCollapsed.value = !isCollapsed.value;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints:
                const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: ReadMoreText(
                reel.descriptionWithUserName,
                style: TextStyleCustom.outFitLight300(
                    color: whitePure(context),
                    opacity: .8,
                    fontSize: 15),
                isCollapsed: _collapsedNotifier,
                annotations: [
                  Annotation(
                    regExp: AppRes.hashTagRegex,
                    spanBuilder: (
                            {required String text,
                            TextStyle? textStyle}) =>
                        TextSpan(
                            text: text,
                            style: textStyle?.copyWith(
                              color: whitePure(context)
                                  .withValues(alpha: .8),
                              fontFamily:
                                  FontRes.outFitMedium500,
                              fontSize: 15,
                            ),
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () async {
                                    await Get.to(
                                        () => HashtagScreen(
                                            hashtag: text),
                                        preventDuplicates:
                                            false);
                                  }),
                  ),
                  Annotation(
                    regExp: AppRes.userNameRegex,
                    spanBuilder: (
                        {required String text,
                        TextStyle? textStyle}) {
                      return TextSpan(
                        text: text,
                        style: textStyle?.copyWith(
                            color: whitePure(context)
                                .withValues(alpha: .8),
                            fontFamily:
                                FontRes.outFitMedium500,
                            fontSize: 15),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            User? user = widget
                                .controller
                                .reelData
                                .value
                                .mentionedUsers
                                ?.firstWhereOrNull(
                                    (element) {
                              return element.username ==
                                  text.replaceAll('@', '');
                            });
                            if (user != null) {
                              NavigationService.shared
                                  .openProfileScreen(user);
                            }
                          },
                      );
                    },
                  ),
                ],
                trimMode: TrimMode.Line,
                trimLines: 3,
                trimCollapsedText: ' ...',
                trimExpandedText: '   ',
                delimiter: '',
                moreStyle: TextStyleCustom.outFitLight300(
                    color: whitePure(context),
                    opacity: .8,
                    fontSize: 15),
                lessStyle: TextStyleCustom.outFitLight300(
                    color: whitePure(context),
                    opacity: .8,
                    fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
