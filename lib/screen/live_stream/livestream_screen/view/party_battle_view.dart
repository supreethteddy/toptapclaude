import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/battle_view.dart';
import 'package:shortzz/utilities/asset_res.dart';
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
            Obx(() => BattleTimer(
                controller: controller, livestream: controller.liveData.value)),
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
      final red = controller.mySideBattleCoins;
      final blue = controller.opponentSideBattleCoins;
      final stream = controller.liveData.value;

      return SafeArea(
        bottom: false,
        child: Container(
          height: Get.height / 2.4,
          width: Get.width,
          margin: margin,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: const EdgeInsets.only(top: 15.0, bottom: 30),
                child: Row(
                  children: [
                    Expanded(child: _SideStack(streamViews: myViews)),
                    Expanded(child: _SideStack(streamViews: opponentViews)),
                  ],
                ),
              ),
              BuildProgressBar(red: red, blue: blue),
              _PartyBattleStats(
                  red: red, blue: blue, controller: controller, stream: stream),
              BuildLastTenSecondView(controller: controller),
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
      children: streamViews
          .map((view) => Expanded(child: view.streamView))
          .toList(),
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
    bool isRedWin = red >= blue;
    AppUser? myHost =
        controller.firestoreController.users.firstWhereOrNull(
            (user) => user.userId == controller.liveData.value.hostId);
    AppUser? opponentHost = controller.opponentLiveData.value == null
        ? null
        : controller.firestoreController.users.firstWhereOrNull((user) =>
            user.userId == controller.opponentLiveData.value?.hostId);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (stream.battleType == BattleType.end)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _winnerTag(context, rightSide: false, isWinner: isRedWin),
                    _winnerTag(context, rightSide: true, isWinner: !isRedWin),
                  ],
                ),
              if (myHost != null || opponentHost != null)
                Container(
                  height: 43,
                  alignment: Alignment.topCenter,
                  child: Row(
                    children: [
                      _streamerInfo(context,
                          isLeft: true,
                          user: myHost,
                          color: ColorRes.likeRed),
                      _streamerInfo(context,
                          isLeft: false,
                          user: opponentHost,
                          color: ColorRes.battleProgressColor),
                    ],
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(AssetRes.icBattleVs, height: 80, width: 80),
          ),
        ],
      ),
    );
  }

  Widget _winnerTag(BuildContext context,
      {required bool rightSide, required bool isWinner}) {
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
              isWinner ? ColorRes.green : ColorRes.likeRed,
              Colors.transparent,
            ],
                begin: !rightSide
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                end: !rightSide
                    ? AlignmentDirectional.centerStart
                    : AlignmentDirectional.centerEnd)),
        child: Text(
          (isWinner ? LKey.victory.tr : LKey.defeat.tr).toUpperCase(),
          style: TextStyleCustom.unboundedBlack900(
              color: isWinner ? ColorRes.green1 : ColorRes.likeRed,
              fontSize: 17),
        ),
      ),
    );
  }

  Widget _streamerInfo(BuildContext context,
      {required bool isLeft, required AppUser? user, required Color color}) {
    return Expanded(
      child: Container(
        height: 43,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: color,
        child: Row(
          mainAxisAlignment:
              isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isLeft && user != null)
              CustomImage(
                  size: const Size(30, 30),
                  strokeColor: whitePure(context),
                  strokeWidth: 1.5,
                  image: user.profile?.addBaseURL(),
                  fullName: user.fullname),
            SizedBox(width: !isLeft ? 30 : 5),
            if (user != null)
              Flexible(
                child: FullNameWithBlueTick(
                  username: user.username,
                  isVerify: user.isVerify,
                  fontColor: whitePure(context),
                  fontSize: 11,
                ),
              ),
            SizedBox(width: isLeft ? 30 : 5),
            if (!isLeft && user != null)
              CustomImage(
                  size: const Size(30, 30),
                  strokeColor: whitePure(context),
                  strokeWidth: 1.5,
                  image: user.profile?.addBaseURL(),
                  fullName: user.fullname),
          ],
        ),
      ),
    );
  }
}
