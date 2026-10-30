import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/pk_gifters.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/gifter_profile_card_sheet.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Ranked gifters for ONE side of the current battle round (tapped from a
/// seat avatar in TopGiftersRow) -- distinct from ContributorRankingSheet,
/// which sums a host's gifts across this ENTIRE LIVE session with no
/// side/round scoping. This reuses the same topGiftersForTeam(...) data
/// TopGiftersRow's own seat avatars are already ranked by, just with a
/// higher limit (10) instead of the 3 seats actually shown, so the two
/// stay consistent with each other by construction. Works for both
/// same-room and cross-room battles since [comments] is whatever the
/// caller already resolved (controller.allBattleComments covers both).
class BattleContributorsSheet extends StatelessWidget {
  final LivestreamScreenController controller;
  final String title;
  final Color color;
  final List<int> teamMemberIds;

  const BattleContributorsSheet({
    super.key,
    required this.controller,
    required this.title,
    required this.color,
    required this.teamMemberIds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
      decoration: ShapeDecoration(
        color: whitePure(context),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          const CustomDivider(width: 130, height: 1),
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: Text(
              "$title's contributors",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyleCustom.unboundedRegular400(
                  color: textDarkGrey(context), fontSize: 15),
            ),
          ),
          const CustomDivider(height: 1),
          Expanded(
            child: Obx(() {
              final stream = controller.liveData.value;
              final ranks = topGiftersForTeam(
                comments: controller.allBattleComments,
                teamMemberIds: teamMemberIds,
                battleCreatedAt: stream.battleCreatedAt,
                eligibleGiftIds: stream.pkEligibleGiftIds,
                limit: 10,
              );
              return NoDataView(
                showShow: ranks.isEmpty,
                title: LKey.noContributorsYetTitle.tr,
                description: LKey.noContributorsYetDescription.tr,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: ranks.length,
                  separatorBuilder: (_, __) => const CustomDivider(),
                  itemBuilder: (context, index) {
                    return _GifterRow(
                      controller: controller,
                      rank: index + 1,
                      gifterRank: ranks[index],
                      color: color,
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _GifterRow extends StatelessWidget {
  final LivestreamScreenController controller;
  final int rank;
  final GifterRank gifterRank;
  final Color color;

  const _GifterRow({
    required this.controller,
    required this.rank,
    required this.gifterRank,
    required this.color,
  });

  Color _rankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFC107);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _rankColor();
    final user = controller.firestoreController.users
        .firstWhereOrNull((u) => u.userId == gifterRank.senderId);
    return InkWell(
      onTap: () => Get.bottomSheet(
        GifterProfileCardSheet(
          userId: gifterRank.senderId,
          controller: controller,
        ),
        isScrollControlled: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: rank <= 3
                  ? Container(
                      height: 26,
                      width: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: badgeColor, shape: BoxShape.circle),
                      child: Text('$rank',
                          style: TextStyleCustom.outFitSemiBold600(
                              color: Colors.white, fontSize: 13)),
                    )
                  : Text('#$rank',
                      textAlign: TextAlign.center,
                      style: TextStyleCustom.outFitMedium500(
                          color: textLightGrey(context), fontSize: 14)),
            ),
            const SizedBox(width: 8),
            CustomImage(
              size: const Size(40, 40),
              image: user?.profile?.addBaseURL(),
              fullName: user?.fullname,
              strokeWidth: rank <= 3 ? 2 : 0,
              strokeColor: badgeColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FullNameWithBlueTick(
                username: user?.username ?? '#${gifterRank.senderId}',
                isVerify: user?.isVerify,
                fontSize: 14,
                iconSize: 16,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${gifterRank.points}',
                style: TextStyleCustom.outFitSemiBold600(
                    color: color, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
