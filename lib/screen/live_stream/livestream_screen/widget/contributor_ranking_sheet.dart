import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/contributor_rank_entry.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Bottom sheet with THIS LIVE session's "Contributor Ranking" (Figma
/// "Live2 (Contributor)"): contributors ordered by total coins gifted during
/// this stream only.
///
/// Distinct from [LiveRankingSheet], which shows the global DAILY ranking of
/// hosts across all their streams. This sheet is scoped to a single room and
/// is backed by [LivestreamScreenController.contributorRanking].
class ContributorRankingSheet extends StatelessWidget {
  final LivestreamScreenController controller;

  const ContributorRankingSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final myId = SessionManager.instance.getUserID();
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
            padding: const EdgeInsets.only(left: 20, right: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 25, height: 25),
                Text(
                  LKey.contributorRanking.tr,
                  style: TextStyleCustom.unboundedRegular400(
                      color: textDarkGrey(context), fontSize: 15),
                ),
                InkWell(
                  onTap: () => _showInfo(context),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: textLightGrey(context),
                  ),
                ),
              ],
            ),
          ),
          const CustomDivider(height: 1),
          Expanded(
            child: Obx(() {
              final items = controller.contributorRanking;
              return NoDataView(
                showShow: items.isEmpty,
                title: LKey.noContributorsYetTitle.tr,
                description: LKey.noContributorsYetDescription.tr,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const CustomDivider(),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    return _ContributorRow(
                      rank: index + 1,
                      entry: entry,
                      isMe: entry.userId == myId,
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

  void _showInfo(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: Text(LKey.contributorRanking.tr),
        content: Text(LKey.contributorRankingInfo.tr),
        actions: [
          TextButton(onPressed: Get.back, child: Text(LKey.close.tr)),
        ],
      ),
    );
  }
}

class _ContributorRow extends StatelessWidget {
  final int rank;
  final ContributorRankEntry entry;
  final bool isMe;

  const _ContributorRow({
    required this.rank,
    required this.entry,
    required this.isMe,
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
    final color = _rankColor();
    final user = entry.user;
    return Container(
      color: isMe ? themeAccentSolid(context).withValues(alpha: .08) : null,
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
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
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
            strokeColor: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FullNameWithBlueTick(
                  username: user?.username ?? '#${entry.userId}',
                  isVerify: user?.isVerify,
                  fontSize: 14,
                  iconSize: 16,
                ),
                Text(
                  '${entry.gifts} ${LKey.gifts.tr}',
                  style: TextStyleCustom.outFitLight300(
                      color: textLightGrey(context), fontSize: 12),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AssetRes.icCoin, height: 16, width: 16),
              const SizedBox(width: 4),
              Text(
                entry.coins.numberFormat,
                style: TextStyleCustom.outFitSemiBold600(
                    color: isMe ? ColorRes.themeColor : textDarkGrey(context),
                    fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
