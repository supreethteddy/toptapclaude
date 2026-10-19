import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/battle_view.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Cross-room PK Battle: this room's side (host + any co-hosts, from
/// [controller.streamViews]) against an independently-run opponent room
/// (from [controller.opponentStreamViews]). Naturally supports 2v2 — a side
/// with a co-host already on screen just has two tiles instead of one, no
/// special-casing needed. For a same-room battle (an existing co-host scored
/// without a separate opponent room), see [BattleView] instead.
class PartyBattleView extends StatelessWidget {
  final LivestreamScreenController controller;
  final EdgeInsets? margin;

  const PartyBattleView({super.key, required this.controller, this.margin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _PartyBattleOverlay(controller: controller, margin: margin),
            // BattleTimer's initState kicks off battleRunning(), which reads
            // battleCreatedAt to compute a countdown and auto-ends the match
            // once it hits zero -- mounting it while merely connected (no
            // battle started yet, battleCreatedAt null) would read that as
            // "already expired" and immediately fire the end-of-battle path.
            // Only mount it once a battle is actually underway or just
            // ended.
            Obx(() {
              final stream = controller.liveData.value;
              if (stream.battleType == BattleType.initiate) {
                return const SizedBox();
              }
              return BattleTimer(controller: controller, livestream: stream);
            }),
          ],
        ),
      ),
    );
  }
}

class _PartyBattleOverlay extends StatelessWidget {
  final LivestreamScreenController controller;
  final EdgeInsets? margin;

  const _PartyBattleOverlay({required this.controller, this.margin});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final myViews = controller.streamViews;
      final opponentViews = controller.opponentStreamViews;
      final stream = controller.liveData.value;
      // Likes tapped on each half of the screen (see onLikeButtonTap) count
      // toward the PK score too, same as the same-room arena already does
      // via pkLikePointsA/B -- crossRoomLikePoints is this doc's own side's
      // tally, reset to 0 at the start of every cross-room match.
      final pointsPerLike = controller.setting?.pkLikePoints ?? 1;
      final red = controller.mySideBattleCoins -
          controller.roundBaselineRed.value +
          (stream.crossRoomLikePoints ?? 0) * pointsPerLike;
      final blue = controller.opponentSideBattleCoins -
          controller.roundBaselineBlue.value +
          (controller.opponentLiveData.value?.crossRoomLikePoints ?? 0) *
              pointsPerLike;

      final inBattle = stream.battleType != BattleType.initiate;

      return SafeArea(
        bottom: false,
        child: Container(
          height: Get.height / 2.4,
          width: Get.width,
          margin: margin,
          // Score bar is a Column sibling ABOVE the video, not an overlay
          // sharing the video's own Stack slot -- matches the same-room
          // arena's proven, already-approved layout (LiveBattleOverlayWidget
          // in battle_view.dart): the bar must never end up hidden behind or
          // under the video. Connecting two hosts without battling (gated by
          // inBattle, same as BattleTimer) must still show both videos only,
          // no score bar/stats/combo badge.
          child: Column(
            children: [
              if (inBattle)
                BuildProgressBar(red: red, blue: blue, showScoreLabels: true),
              Expanded(
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Row(
                        children: [
                          Expanded(child: _SideStack(streamViews: myViews)),
                          Expanded(
                              child: _SideStack(streamViews: opponentViews)),
                        ],
                      ),
                    ),
                    if (inBattle) ...[
                      _PartyBattleStats(
                          red: red,
                          blue: blue,
                          controller: controller,
                          stream: stream),
                      GiftComboBadge(controller: controller),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// One side's video tile(s) stacked vertically — 1 for a solo host, 2 for a
/// room that already has a co-host (making this side's team a 2v2 half).
class _SideStack extends StatelessWidget {
  final List<StreamView> streamViews;

  const _SideStack({required this.streamViews});

  @override
  Widget build(BuildContext context) {
    if (streamViews.isEmpty) {
      return Container(color: Colors.grey[900]);
    }
    return Column(
      children:
          streamViews.map((view) => Expanded(child: view.streamView)).toList(),
    );
  }
}

class _PartyBattleStats extends StatelessWidget {
  final int red;
  final int blue;
  final LivestreamScreenController controller;
  final Livestream stream;

  const _PartyBattleStats(
      {required this.red,
      required this.blue,
      required this.controller,
      required this.stream});

  @override
  Widget build(BuildContext context) {
    // Was `red >= blue`, which silently counted a tie as a red win — the
    // post-battle tag would say "VICTORY"/"DEFEAT" on a genuinely equal
    // score, contradicting `_recordBattleHistory`'s outcome check (and the
    // spec's "declare DRAW if equal"). determineBattleOutcome is the same
    // shared, unit-tested function that side uses.
    final outcome = determineBattleOutcome(red, blue);
    bool isDraw = outcome == BattleOutcome.draw;
    bool isRedWin = outcome == BattleOutcome.sideAWins;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FirstGiftBonusBanner(controller: controller),
              Obx(() => controller.isOpponentReconnecting.value
                  ? Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        LKey.opponentReconnecting.tr,
                        style: TextStyleCustom.outFitMedium500(
                            color: Colors.white, fontSize: 11),
                      ),
                    )
                  : const SizedBox()),
              if (stream.battleType == BattleType.end) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _winnerTag(context,
                        rightSide: false, isWinner: isRedWin, isDraw: isDraw),
                    _winnerTag(context,
                        rightSide: true, isWinner: !isRedWin, isDraw: isDraw),
                  ],
                ),
                if (controller.isHost && controller.canStartNextRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: InkWell(
                      onTap: controller.startNextRound,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: whitePure(context).withValues(alpha: .15),
                            border: Border.all(
                                color:
                                    whitePure(context).withValues(alpha: .3))),
                        child: Text(
                          LKey.nextRound.tr,
                          style: TextStyleCustom.outFitSemiBold600(
                              color: whitePure(context), fontSize: 14),
                        ),
                      ),
                    ),
                  )
                // Whole match concluded (no rounds left), not just one
                // round — this is where a rematch (a brand-new battle) makes
                // sense, as opposed to "Next Round" which continues the
                // current match.
                else if (controller.isHost && !controller.canStartNextRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: InkWell(
                      onTap: controller.requestRematch,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: ColorRes.likeRed),
                        child: Text(
                          LKey.rematch.tr,
                          style: TextStyleCustom.outFitSemiBold600(
                              color: whitePure(context), fontSize: 14),
                        ),
                      ),
                    ),
                  ),
              ],
              // Top-3 gifters seat row for each side, right at the bottom
              // edge of the video (client reference) -- replaces the plain
              // red/blue hostname strip this used to be.
              TopGiftersRow(
                controller: controller,
                teamAUserIds: [
                  if (stream.hostId != null) stream.hostId!,
                ],
                teamBUserIds: [
                  if (controller.opponentLiveData.value?.hostId != null)
                    controller.opponentLiveData.value!.hostId!,
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _winnerTag(BuildContext context,
      {required bool rightSide, required bool isWinner, bool isDraw = false}) {
    final tagColor =
        isDraw ? Colors.grey : (isWinner ? ColorRes.green : ColorRes.likeRed);
    return Expanded(
      child: Container(
        height: 31,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: rightSide
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [
              tagColor,
              Colors.transparent,
            ],
                begin: !rightSide
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                end: !rightSide
                    ? AlignmentDirectional.centerStart
                    : AlignmentDirectional.centerEnd)),
        child: Text(
          (isDraw
                  ? LKey.battleDraw.tr
                  : (isWinner ? LKey.victory.tr : LKey.defeat.tr))
              .toUpperCase(),
          style: TextStyleCustom.unboundedBlack900(
              color: isDraw
                  ? Colors.grey
                  : (isWinner ? ColorRes.green1 : ColorRes.likeRed),
              fontSize: 17),
        ),
      ),
    );
  }

}
