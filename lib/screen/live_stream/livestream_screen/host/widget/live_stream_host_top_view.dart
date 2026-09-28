import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/contributor_top_badges.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_goal_progress_widget.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Host top toolbar:
/// [avatar] [username + daily rank] [LIVE title ✎]   [goal] [👁 viewers] [⏻]
///
/// Likes received live in the bottom bar (see LiveStreamBottomView) and the
/// PK / guests controls live in the host control row.
class LiveStreamHostTopView extends StatelessWidget {
  final LivestreamScreenController controller;

  const LiveStreamHostTopView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      minimum: EdgeInsets.only(top: AppBar().preferredSize.height * 0.3),
      child: Obx(() {
        Livestream stream = controller.liveData.value;
        int count = stream.watchingCount ?? 0;
        int watchingCount = count >= 0 ? count : 0;
        bool isVisible = controller.isViewVisible.value;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: isVisible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HostAvatar(controller: controller),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                controller.myUser.value?.username ?? 'User',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyleCustom.outFitSemiBold600(
                                  color: whitePure(context),
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            LiveRankChip(controller: controller),
                          ],
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: controller.showEditLiveTitleDialog,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  (stream.description ?? '').trim().isEmpty
                                      ? 'Add LIVE title'
                                      : stream.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyleCustom.outFitRegular400(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.edit,
                                color: Colors.white70,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Goal chip lives in the toolbar row (client request L-02).
                  Flexible(
                    flex: 0,
                    child: LiveGoalProgressWidget(
                        controller: controller, compact: true),
                  ),
                  if (stream.hasLiveGoal == true) const SizedBox(width: 6),

                  // Top-3 contributor badges for THIS LIVE session
                  // (Figma "Live1"), next to the viewer count. Tap opens the
                  // full Contributor Ranking sheet.
                  ContributorTopBadges(controller: controller),
                  const SizedBox(width: 6),

                  // Viewer count -> opens the audience list.
                  GestureDetector(
                    onTap: () {
                      HapticManager.shared.light();
                      controller.openAudienceSheet();
                    },
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AssetRes.icEye_2,
                            height: 15,
                            width: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            watchingCount.numberFormat,
                            style: TextStyleCustom.outFitMedium500(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Stop button
                  GestureDetector(
                    onTap: controller.onStopButtonTap,
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: const BoxDecoration(
                        color: ColorRes.likeRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.power_settings_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  final LivestreamScreenController controller;

  const _HostAvatar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final photo = controller.myUser.value?.profilePhoto ?? '';
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(
        child: photo.isNotEmpty
            ? Image.network(
                photo.addBaseURL(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, color: Colors.white, size: 20),
              )
            : const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }
}

/// "#N Today" chip next to the host name. Tap to open the daily ranking.
class LiveRankChip extends StatelessWidget {
  final LivestreamScreenController controller;

  const LiveRankChip({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final ranking = controller.rankingController;
    if (ranking == null) return const SizedBox();
    return Obx(() {
      final rank = ranking.hostRank.value;
      final label = rank == 0 ? '—' : '#$rank';
      return GestureDetector(
        onTap: controller.openRankingSheet,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AssetRes.icCrown,
                  height: 12, width: 12, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                '$label ${LKey.today.tr}',
                style: TextStyleCustom.outFitSemiBold600(
                    color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class StopLiveStreamSheet extends StatelessWidget {
  final VoidCallback onTap;
  final String? title;
  final String? description;
  final String? positiveText;

  const StopLiveStreamSheet({
    super.key,
    required this.onTap,
    this.title,
    this.description,
    this.positiveText,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          width: double.infinity,
          decoration: ShapeDecoration(
            color: adaptiveBackground(context),
            shape: const SmoothRectangleBorder(
              side: BorderSide(),
              borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 40, cornerSmoothing: 1),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: .5,
                  color: textLightGrey(context),
                  width: 100,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                title ?? LKey.endStreamTitle.tr,
                style: TextStyleCustom.unboundedRegular400(
                  fontSize: 15,
                  color: adaptiveTextColor(context),
                ),
              ),
              Text(
                description ?? LKey.endStreamMessage.tr,
                style: TextStyleCustom.outFitLight300(
                  fontSize: 17,
                  color: ColorRes.textlightGreenColor,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: TextButtonCustom(
                      onTap: Get.back,
                      title: LKey.cancel.tr,
                      titleColor: textDarkGrey(context),
                      backgroundColor: bgLightGrey(context),
                      borderSide: BorderSide(color: bgGrey(context)),
                    ),
                  ),
                  Expanded(
                    child: TextButtonCustom(
                      onTap: () {
                        Get.back();
                        onTap();
                      },
                      title: positiveText ?? LKey.yes.tr,
                      backgroundColor: themeAccentSolid(context),
                      titleColor: whitePure(context),
                      horizontalMargin: 5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppBar().preferredSize.height),
            ],
          ),
        ),
      ],
    );
  }
}

class LiveStreamBorderButton extends StatelessWidget {
  final Color? backgroundColor;
  final String title;
  final String imageIcon;
  final Color? imageColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  const LiveStreamBorderButton({
    super.key,
    this.backgroundColor,
    required this.title,
    this.imageIcon = '',
    this.imageColor,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    double width = Get.width / 5.5;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 30,
        width: width,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(cornerRadius: 30),
            side: BorderSide(color: whitePure(context).withValues(alpha: .3)),
          ),
          shadows: shadow,
          color: backgroundColor ?? blackPure(context).withValues(alpha: .1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 3,
          children: [
            if (imageIcon.isNotEmpty)
              Image.asset(imageIcon, height: 16, width: 16, color: imageColor),
            Text(
              title,
              style: TextStyleCustom.outFitRegular400(
                color: whitePure(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveStreamCircleBorderButton extends StatelessWidget {
  final String image;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Size? size;
  final Color? iconColor;
  final Color? borderColor;
  final Color? bgColor;
  final double? iconSize;

  const LiveStreamCircleBorderButton({
    super.key,
    required this.image,
    this.margin,
    this.onTap,
    this.size,
    this.iconColor,
    this.borderColor,
    this.iconSize,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticManager.shared.light();
        onTap?.call();
      },
      child: Container(
        height: size?.height ?? 32,
        width: size?.width ?? 32,
        margin: margin,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(cornerRadius: 30),
            side: BorderSide(
              color: borderColor ?? whitePure(context).withValues(alpha: .3),
            ),
          ),
          color: (bgColor ?? blackPure(context)).withValues(alpha: .1),
        ),
        child: Image.asset(
          image,
          height: iconSize ?? 20,
          width: iconSize ?? 20,
          color: iconColor ?? whitePure(context).withValues(alpha: .3),
        ),
      ),
    );
  }
}

final livestreamShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: .15),
    offset: const Offset(0, 2),
    blurRadius: 5,
  ),
];
