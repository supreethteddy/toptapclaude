import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/duration_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/battle_result.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/pk_gifters.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_view.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class BattleView extends StatefulWidget {
  final bool isAudience;
  final LivestreamScreenController controller;
  final EdgeInsets? margin;

  const BattleView(
      {super.key,
      this.isAudience = false,
      required this.controller,
      this.margin});

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> {
  @override
  Widget build(BuildContext context) {
    // The match timer / Victory lap countdown now overlay the video itself
    // (see LiveBattleOverlayWidget) instead of sitting in a row below it.
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        child: LiveBattleOverlayWidget(
            controller: widget.controller, margin: widget.margin),
      ),
    );
  }
}

class LiveBattleOverlayWidget extends StatefulWidget {
  final LivestreamScreenController controller;
  final EdgeInsets? margin;

  const LiveBattleOverlayWidget(
      {super.key, required this.controller, this.margin});

  @override
  State<LiveBattleOverlayWidget> createState() =>
      _LiveBattleOverlayWidgetState();
}

class _LiveBattleOverlayWidgetState extends State<LiveBattleOverlayWidget> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Livestream stream = widget.controller.liveData.value;
      List<AppUser> liveUsers = widget.controller.firestoreController.users;
      List<StreamView> streamViews = widget.controller.streamViews;

      // Team membership (pkTeamAIds/pkTeamBIds, falling back to host/first-
      // co-host for any battle predating them) rather than screen position —
      // a guest tile or future 2v2 co-host sitting at streamViews[1] used to
      // silently become "the opponent" here. 1v1 only for now, so each team
      // is exactly one user.
      final teamAIds = widget.controller.pkTeamAUserIds;
      final teamBIds = widget.controller.pkTeamBUserIds;
      final teamAId = teamAIds.isEmpty ? null : teamAIds.first;
      final teamBId = teamBIds.isEmpty ? null : teamBIds.first;
      AppUser? hostUser = teamAId == null
          ? null
          : liveUsers.firstWhereOrNull((u) => u.userId == teamAId);
      AppUser? coHostUser = teamBId == null
          ? null
          : liveUsers.firstWhereOrNull((u) => u.userId == teamBId);
      // Each team's own tile, kept in its own fixed slot even when their
      // stream has dropped — collapsing the Row to one tile when a co-host
      // disconnects used to silently relabel the remaining tile as "both
      // sides"; now that slot shows a reconnecting placeholder instead.
      StreamView? teamAView = teamAId == null
          ? null
          : streamViews.firstWhereOrNull((v) => v.streamId == '$teamAId');
      StreamView? teamBView = teamBId == null
          ? null
          : streamViews.firstWhereOrNull((v) => v.streamId == '$teamBId');

      // Team scores (gift coins since this round's baseline, respecting any
      // eligible-gift restriction the match was set up with, plus likes
      // tapped on that side) via the same pkTeamScore the match's saved
      // history uses, instead of reading one side's currentBattleCoin by
      // screen position.
      int red = widget.controller.pkTeamAScore().total;
      int blue = widget.controller.pkTeamBScore().total;

      final isEnded = stream.battleType == BattleType.end;
      final outcome = determineBattleOutcome(red, blue);
      final isDraw = outcome == BattleOutcome.draw;
      final isRedWin = outcome == BattleOutcome.sideAWins;
      final hostWins = stream.battleRoundWinsHost ?? 0;
      final coHostWins = stream.battleRoundWinsCoHost ?? 0;

      return SafeArea(
        bottom: false,
        child: Container(
          height: Get.height / 2.4,
          width: Get.width,
          margin: widget.margin,
          // The score bar is a Column sibling ABOVE the video, not an
          // overlay sharing the same top-aligned Stack slot the video
          // itself uses — client spec: the bar sits above the video, never
          // behind or below it.
          child: Column(
            children: [
              BuildProgressBar(red: red, blue: blue, showScoreLabels: true),
              Expanded(
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Row(
                        children: [
                          Expanded(child: _buildSlot(teamAView, hostUser)),
                          Expanded(child: _buildSlot(teamBView, coHostUser)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: isEnded
                            ? VictoryLapTimer(controller: widget.controller)
                            : BattleTimer(
                                controller: widget.controller,
                                livestream: stream),
                      ),
                    ),
                    // Each side's running match-win tally, visible for the
                    // whole match (client reference shows "WIN x1" already
                    // up while the next match against that same opponent is
                    // still in progress) — the losing side swaps to a plain
                    // LOSE tag only once the match actually ends.
                    Positioned(
                      top: 8,
                      left: 10,
                      child: (isEnded && !isDraw && !isRedWin)
                          ? const ResultPill(isDraw: false)
                          : (isEnded && isDraw)
                              ? const ResultPill(isDraw: true)
                              : WinPill(count: hostWins, color: ColorRes.likeRed),
                    ),
                    Positioned(
                      top: 8,
                      right: 10,
                      child: (isEnded && !isDraw && isRedWin)
                          ? const ResultPill(isDraw: false)
                          : (isEnded && isDraw)
                              ? const ResultPill(isDraw: true)
                              : WinPill(
                                  count: coHostWins,
                                  color: ColorRes.battleProgressColor),
                    ),
                    BuildBottomInfo(
                        stream: stream, controller: widget.controller),
                    BuildLastTenSecondView(controller: widget.controller),
                    GiftComboBadge(controller: widget.controller),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSlot(StreamView? view, AppUser? user) {
    if (view != null) {
      return LiveStreamUserView(
        isNameAndSpeakerVisible: false,
        controller: widget.controller,
        streamingView: view,
      );
    }
    if (user == null) return const SizedBox();
    return ReconnectingPlaceholder(user: user);
  }
}

/// A PK team member whose stream has dropped — same slot, same side, not
/// collapsed out of the layout, so the other tile never silently becomes
/// "the whole screen".
class ReconnectingPlaceholder extends StatelessWidget {
  final AppUser user;

  const ReconnectingPlaceholder({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(LKey.reconnectingCreator.tr,
              style: TextStyleCustom.outFitSemiBold600(
                  color: Colors.white, fontSize: 13)),
          const SizedBox(height: 2),
          Text(LKey.creatorWillBeBackSoon.tr,
              style: TextStyleCustom.outFitRegular400(
                  color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Per-tile "WIN" / "LOSE" badge shown once the match ends — replaces the
/// shared gradient VICTORY/DEFEAT tags that used to sit below the video for
/// both sides at once with the same top-corner placement the reference
/// client's PK arena uses.
class ResultPill extends StatelessWidget {
  final bool isDraw;

  const ResultPill({super.key, required this.isDraw});

  @override
  Widget build(BuildContext context) {
    final label = isDraw ? LKey.battleDraw.tr.toUpperCase() : LKey.lose.tr;
    final bgColor = isDraw
        ? Colors.grey.withValues(alpha: .85)
        : Colors.black.withValues(alpha: .6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyleCustom.outFitSemiBold600(
              color: Colors.white, fontSize: 12)),
    );
  }
}

/// Replaces the plain post-match timer with a "🎉 Victory lap mm:ss"
/// countdown once the match ends — the same centered slot the running
/// match's BattleTimer occupies, just relabelled.
class VictoryLapTimer extends StatelessWidget {
  final LivestreamScreenController controller;

  const VictoryLapTimer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final duration =
          Duration(seconds: controller.victoryLapSecondsRemaining.value);
      return FittedBox(
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: whitePure(context),
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text('${LKey.victoryLap.tr} ${duration.printDuration}',
                  style: TextStyleCustom.unboundedMedium500(
                      color: ColorRes.green, fontSize: 14)),
            ],
          ),
        ),
      );
    });
  }
}

/// Transient "xN" badge for [LivestreamScreenController.currentGiftComboCount]
/// — a viewer rapid-firing the same gift. Hidden once the combo count drops
/// back to 0 (streak window elapsed with no further matching gift).
class GiftComboBadge extends StatelessWidget {
  final LivestreamScreenController controller;

  const GiftComboBadge({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.currentGiftComboCount.value;
      if (count <= 1) return const SizedBox();
      final gift = controller.currentGiftComboComment.value?.gift;
      return Align(
        alignment: Alignment.center,
        child: AnimatedScale(
          scale: 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gift?.image != null)
                  CustomImage(
                      size: const Size(24, 24),
                      image: gift!.image?.addBaseURL()),
                if (gift?.image != null) const SizedBox(width: 6),
                Text(
                  'x$count',
                  style: TextStyleCustom.unboundedExtraBold800(
                      color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class BuildProgressBar extends StatelessWidget {
  final int red;
  final int blue;
  // Same-room PK Match only (see LiveBattleOverlayWidget) — the raw score
  // numbers at each end of the bar. Defaults off so the cross-room view
  // (PartyBattleView, which reuses this same widget) is unaffected.
  final bool showScoreLabels;

  const BuildProgressBar({
    super.key,
    required this.red,
    required this.blue,
    this.showScoreLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = Get.width;
    final total = red + blue == 0 ? 1 : red + blue; // prevent division by zero

    final redWidth = (width * red) / total;
    final blueWidth = (width * blue) / total;
    final alignmentX = ((redWidth / width) * 2) - 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  height: 10,
                  width: redWidth,
                  color: ColorRes.likeRed,
                  duration: const Duration(milliseconds: 200),
                ),
                AnimatedContainer(
                  height: 10,
                  width: blueWidth,
                  color: ColorRes.battleProgressColor,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
            if (showScoreLabels) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _ScoreLabel(score: red, color: ColorRes.likeRed),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _ScoreLabel(score: blue, color: ColorRes.battleProgressColor),
              ),
            ],
            AnimatedAlign(
              alignment: Alignment(alignmentX, 0),
              duration: const Duration(milliseconds: 200),
              child: Container(
                height: 30,
                width: 30,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: whitePure(context),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Image.asset(AssetRes.icCrown, height: 14, width: 19),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreLabel extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreLabel({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.rectangle),
      child: Text(
        score.numberFormat,
        style: TextStyleCustom.outFitSemiBold600(
            color: Colors.white, fontSize: 12),
      ),
    );
  }
}

/// "WIN xN" pill for one side's running match-win tally. Shared by the
/// cross-room multi-round battle (PartyBattleView, counts rounds within one
/// match) and the same-room PK Match arena (counts separate matches won
/// against the same opponent across rematches within this LIVE session —
/// see battleRoundWinsHost/CoHost and LivestreamScreenController._startPkMatch).
class WinPill extends StatelessWidget {
  final int count;
  final Color color;

  const WinPill({super.key, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${LKey.win.tr} x$count',
        style:
            TextStyleCustom.outFitSemiBold600(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

/// "Round {current}/{total}" label for the fixed round count per match.
/// Cross-room only now (PartyBattleView) — see [WinPill].
class RoundLabel extends StatelessWidget {
  final int current;
  final int total;

  const RoundLabel({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${LKey.round.tr} $current/$total',
      style: TextStyleCustom.outFitMedium500(
          color: Colors.white70, fontSize: 11),
    );
  }
}

/// "First Gift x3 gifting points | Ns" countdown banner: visible for
/// AppRes.firstGiftBonusWindowInSecond after a round starts, until someone
/// claims the bonus (LivestreamScreenController._claimFirstGiftBonusIfEligible)
/// or the window elapses. Shared by both battle views.
class FirstGiftBonusBanner extends StatefulWidget {
  final LivestreamScreenController controller;

  const FirstGiftBonusBanner({super.key, required this.controller});

  @override
  State<FirstGiftBonusBanner> createState() => _FirstGiftBonusBannerState();
}

class _FirstGiftBonusBannerState extends State<FirstGiftBonusBanner> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // The countdown text depends on wall-clock elapsed time, not an Rx
    // value, so a plain periodic rebuild drives the ticking; Obx below
    // still reacts immediately once firstGiftBonusClaimed flips true.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stream = widget.controller.liveData.value;
      if (stream.battleType != BattleType.waiting) return const SizedBox();
      if (stream.firstGiftBonusClaimed == true) return const SizedBox();
      final createdAt = stream.battleCreatedAt;
      if (createdAt == null) return const SizedBox();
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - createdAt) ~/ 1000;
      final remaining = AppRes.firstGiftBonusWindowInSecond - elapsed;
      if (remaining <= 0) return const SizedBox();
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${LKey.firstGiftBonus.trParams({
                'multiplier': '${AppRes.firstGiftBonusMultiplier}'
              })} | ${remaining}s',
          style: TextStyleCustom.outFitMedium500(
              color: Colors.white, fontSize: 11),
        ),
      );
    });
  }
}

/// Bottom-of-arena content: the first-gift-bonus banner, each player's name
/// strip, and — once the match ends — a single host-only action button
/// (Next Round for a multi-round match, otherwise Rematch). The shared
/// VICTORY/DEFEAT tags and the floating VS logo this used to render here are
/// gone: the result is now the per-tile ResultPill at the top of the arena,
/// and no VS logo is shown once a match is actually under way (the client's
/// reference only shows that in the pre-match setup/invite cards).
class BuildBottomInfo extends StatelessWidget {
  final Livestream stream;
  final LivestreamScreenController controller;

  const BuildBottomInfo(
      {super.key, required this.stream, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isEnded = stream.battleType == BattleType.end;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FirstGiftBonusBanner(controller: controller),
          if (isEnded && controller.isHost)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: InkWell(
                onTap: controller.canStartNextRound
                    ? controller.startNextRound
                    : controller.openPkMatchSetupSheet,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF3D6E), Color(0xFF7C4DFF)]),
                  ),
                  child: Text(
                    controller.canStartNextRound
                        ? LKey.nextRound.tr
                        : LKey.rematch.tr,
                    style: TextStyleCustom.outFitSemiBold600(
                        color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          TopGiftersRow(controller: controller),
        ],
      ),
    );
  }
}

/// Each side's top-3 gifters for the current match, ranked closest-to-
/// center outward, empty seats filling whatever's left — replaces the
/// plain red/blue username strip with the leaderboard row the client's
/// reference shows between the video and the comment feed. Ranking is
/// derived from the existing comment stream (see topGiftersForTeam) rather
/// than a new Firestore field.
class TopGiftersRow extends StatelessWidget {
  final LivestreamScreenController controller;

  const TopGiftersRow({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stream = controller.liveData.value;
      final comments = controller.comments;
      final teamARanks = topGiftersForTeam(
        comments: comments,
        teamMemberIds: controller.pkTeamAUserIds,
        battleCreatedAt: stream.battleCreatedAt,
        eligibleGiftIds: stream.pkEligibleGiftIds,
      );
      final teamBRanks = topGiftersForTeam(
        comments: comments,
        teamMemberIds: controller.pkTeamBUserIds,
        battleCreatedAt: stream.battleCreatedAt,
        eligibleGiftIds: stream.pkEligibleGiftIds,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _teamSlots(teamARanks, ColorRes.likeRed, rankOneNearCenter: true),
            _teamSlots(teamBRanks, ColorRes.battleProgressColor,
                rankOneNearCenter: false),
          ],
        ),
      );
    });
  }

  // Rank 1 sits nearest the center on both sides. The left team's slots are
  // built worst-to-best left-to-right so the best (last) lands innermost;
  // the right team is already worst-to-best outward-to-inward as built.
  Widget _teamSlots(List<GifterRank> ranks, Color color,
      {required bool rankOneNearCenter}) {
    final slots = List<GifterRank?>.generate(
        3, (i) => i < ranks.length ? ranks[i] : null);
    final ordered = rankOneNearCenter ? slots.reversed.toList() : slots;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ordered
          .map((rank) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: rank == null
                    ? _EmptySeat(color: color)
                    : _GifterAvatar(controller: controller, rank: rank, color: color),
              ))
          .toList(),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  final Color color;

  const _EmptySeat({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 34,
      decoration:
          BoxDecoration(color: color.withValues(alpha: .35), shape: BoxShape.circle),
      child: const Icon(Icons.event_seat, color: Colors.white70, size: 16),
    );
  }
}

class _GifterAvatar extends StatelessWidget {
  final LivestreamScreenController controller;
  final GifterRank rank;
  final Color color;

  const _GifterAvatar(
      {required this.controller, required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    final user = controller.firestoreController.users
        .firstWhereOrNull((u) => u.userId == rank.senderId);
    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
      child: ClipOval(
        child: CustomImage(
          size: const Size(30, 30),
          image: user?.profile?.addBaseURL(),
          fullName: user?.fullname,
        ),
      ),
    );
  }
}

class BuildLastTenSecondView extends StatefulWidget {
  final LivestreamScreenController controller;

  const BuildLastTenSecondView({super.key, required this.controller});

  @override
  State<BuildLastTenSecondView> createState() => _BuildLastTenSecondViewState();
}

class _BuildLastTenSecondViewState extends State<BuildLastTenSecondView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    super.initState();
  }

  @override
  void dispose() {
    Loggers.error('Dispose');
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Livestream stream = widget.controller.liveData.value;
      bool isBattleEnd = stream.battleType == BattleType.end;
      int leftSecond = widget.controller.remainingBattleSeconds.value;

      if (leftSecond == 0 || isBattleEnd) {
        return const SizedBox();
      }
      if (leftSecond <= 10) {
        return Align(
          alignment: const Alignment(0, -0.2),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Container(
              height: 150,
              width: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                    colors: <Color>[
                      whitePure(context).withValues(alpha: 0),
                      whitePure(context).withValues(alpha: .5)
                    ],
                    transform:
                        GradientRotation(2 * pi * _animationController.value)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Text('$leftSecond',
                    style: TextStyleCustom.unboundedBlack900(
                        color: whitePure(context), fontSize: 100),
                    key: ValueKey<int>(leftSecond)),
              ),
            ),
          ),
        );
      }
      return const SizedBox();
    });
  }
}

class BattleTimer extends StatefulWidget {
  final LivestreamScreenController controller;
  final Livestream livestream;

  const BattleTimer(
      {super.key, required this.controller, required this.livestream});

  @override
  State<BattleTimer> createState() => _BattleTimerState();
}

class _BattleTimerState extends State<BattleTimer> {
  @override
  void initState() {
    super.initState();
    widget.controller.battleRunning();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      int leftSecond = widget.controller.remainingBattleSeconds.value;
      Duration duration = Duration(seconds: leftSecond);
      Livestream stream = widget.controller.liveData.value;
      bool isBattleEnd = stream.battleType == BattleType.end;

      return AnimatedOpacity(
        opacity: isBattleEnd
            ? 0
            : leftSecond <= 0
                ? 0
                : 1,
        duration: const Duration(milliseconds: 250),
        child: FittedBox(
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: whitePure(context),
              borderRadius: BorderRadius.circular(30),
            ),
            alignment: Alignment.center,
            child: Text(
              duration.printDuration,
              style: TextStyleCustom.unboundedMedium500(
                  color: isBattleEnd
                      ? ColorRes.likeRed
                      : themeAccentSolid(context),
                  fontSize: 18),
            ),
          ),
        ),
      );
    });
  }
}
