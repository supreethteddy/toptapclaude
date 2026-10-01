import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_app_bar.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/screen/battle_history_screen/battle_history_screen_controller.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class BattleHistoryScreen extends StatelessWidget {
  const BattleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BattleHistoryScreenController());
    return Scaffold(
      body: Column(
        children: [
          const CustomAppBar(title: 'Battle History'),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  _StatsRow(controller: controller),
                  const SizedBox(height: 10),
                  Expanded(
                    child: NoDataView(
                      showShow: controller.battles.isEmpty,
                      title: 'No battles yet',
                      description: 'Your PK Battle history will show up here.',
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: controller.battles.length,
                        itemBuilder: (context, index) {
                          final battle = controller.battles[index];
                          return _BattleRow(
                            battle: battle,
                            myUserId: controller.myUserId,
                            opponent: controller.opponentOf(battle),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final BattleHistoryScreenController controller;

  const _StatsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatTile(label: 'Battles', value: '${controller.totalBattles}'),
          _StatTile(label: 'Wins', value: '${controller.wins}'),
          _StatTile(label: 'Losses', value: '${controller.losses}'),
          _StatTile(label: 'Draws', value: '${controller.draws}'),
          _StatTile(label: 'Win Rate', value: controller.winRateDisplay),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyleCustom.unboundedSemiBold600(
                  fontSize: 16, color: textDarkGrey(context))),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyleCustom.outFitLight300(
                  fontSize: 11, color: textLightGrey(context))),
        ],
      ),
    );
  }
}

class _BattleRow extends StatelessWidget {
  final BattleResult battle;
  final int myUserId;
  final AppUser? opponent;

  const _BattleRow({
    required this.battle,
    required this.myUserId,
    required this.opponent,
  });

  @override
  Widget build(BuildContext context) {
    final myScore = battle.scoreFor(myUserId);
    final opponentId = battle.opponentIdFor(myUserId);
    final opponentScore =
        opponentId == null ? 0 : battle.scoreFor(opponentId);
    final isWin = !battle.isDraw && battle.winnerHostId == myUserId;
    final isDraw = battle.isDraw;
    final resultLabel = isDraw ? 'DRAW' : (isWin ? 'WIN' : 'LOSS');
    final resultColor =
        isDraw ? Colors.grey : (isWin ? ColorRes.green : ColorRes.likeRed);
    final endedAt = DateTime.fromMillisecondsSinceEpoch(battle.battleEndedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CustomImage(
            size: const Size(44, 44),
            image: opponent?.profile?.addBaseURL(),
            fullName: opponent?.fullname,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent?.username ?? 'Unknown opponent',
                  style: TextStyleCustom.outFitSemiBold600(
                      fontSize: 14, color: textDarkGrey(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$myScore - $opponentScore  •  ${_formatDate(endedAt)}',
                  style: TextStyleCustom.outFitLight300(
                      fontSize: 12, color: textLightGrey(context)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              resultLabel,
              style: TextStyleCustom.outFitSemiBold600(
                  fontSize: 12, color: resultColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$day ${months[d.month - 1]} ${d.year}';
  }
}
