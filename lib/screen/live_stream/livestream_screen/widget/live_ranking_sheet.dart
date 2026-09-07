import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/live_ranking_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Bottom sheet with today's LIVE ranking (hosts ordered by coins received).
class LiveRankingSheet extends StatelessWidget {
  final LiveRankingController controller;

  const LiveRankingSheet({super.key, required this.controller});

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
          BottomSheetTopView(
              title: LKey.dailyRanking.tr, sideBtnVisibility: false),
          Obx(() {
            final rank = controller.hostRank.value;
            final coins = controller.hostCoins.value;
            return Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
              child: Row(
                children: [
                  Image.asset(AssetRes.icCrown, height: 18, width: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rank == 0
                          ? LKey.notRankedYet.tr
                          : '${LKey.yourRankToday.tr}: #$rank  •  ${coins.numberFormat} ${LKey.coins.tr}',
                      style: TextStyleCustom.outFitMedium500(
                          color: textDarkGrey(context), fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }),
          const CustomDivider(),
          Expanded(
            child: Obx(() {
              if (!controller.isLoaded.value) return const LoaderWidget();
              final items = controller.entries;
              return NoDataView(
                showShow: items.isEmpty,
                title: LKey.noRankingYetTitle.tr,
                description: LKey.noRankingYetDescription.tr,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const CustomDivider(),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    final user = entry.user ??
                        Get.find<FirebaseFirestoreController>()
                            .users
                            .firstWhereOrNull(
                                (u) => u.userId == entry.hostId);
                    return _RankRow(
                      rank: index + 1,
                      entry: entry,
                      user: user,
                      isMe: entry.hostId == myId,
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

class _RankRow extends StatelessWidget {
  final int rank;
  final LiveRankEntry entry;
  final AppUser? user;
  final bool isMe;

  const _RankRow({
    required this.rank,
    required this.entry,
    required this.user,
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
                  username: user?.username ?? '#${entry.hostId}',
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
