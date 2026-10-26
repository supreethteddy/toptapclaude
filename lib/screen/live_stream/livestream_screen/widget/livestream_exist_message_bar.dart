import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/duration_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LivestreamExistMessageBar extends StatefulWidget {
  final LivestreamScreenController controller;
  final Livestream stream;

  const LivestreamExistMessageBar(
      {super.key, required this.controller, required this.stream});

  @override
  State<LivestreamExistMessageBar> createState() =>
      _LivestreamExistMessageBarState();
}

class _LivestreamExistMessageBarState extends State<LivestreamExistMessageBar> {
  late final RxInt currentSecLeft;
  Timer? _timer;

  bool get isBattleView => widget.stream.type == LivestreamType.battle;

  @override
  void initState() {
    super.initState();
    startCountDown();
  }

  // Client spec 9.4 (clarified 2026-10-26): the post-match window is 3
  // minutes total (AppRes.pkVictoryLapDurationInSecond) from the shared
  // battleEndedAt timestamp every device reads -- not a fresh local
  // countdown seeded at whatever moment this bar happens to mount, which
  // is what let a remount/late-join skew this bar out of sync with the
  // actual arena display (see PostBattlePhase/postBattlePhaseFor in
  // pk_scores.dart, which the arena views key off the same timestamp for).
  void startCountDown() async {
    if (!isBattleView) {
      currentSecLeft = 10.obs;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (currentSecLeft.value <= 1) {
          _timer?.cancel();
          widget.controller.hostEndStream();
        } else {
          currentSecLeft.value--;
        }
      });
      return;
    }

    final battleEndedAt = widget.stream.battleEndedAt;
    final elapsedSeconds = battleEndedAt == null
        ? 0
        : (DateTime.now().millisecondsSinceEpoch - battleEndedAt) ~/ 1000;
    currentSecLeft = (AppRes.pkVictoryLapDurationInSecond - elapsedSeconds)
        .clamp(0, AppRes.pkVictoryLapDurationInSecond)
        .obs;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      Loggers.info('[BATTLE END] Victory Lap resets in $currentSecLeft sec.');
      if (currentSecLeft.value <= 1) {
        _timer?.cancel();
        unawaited(widget.controller.updateUserStateToFirestore(
            widget.controller.myUserId,
            currentBattleCoin: 0));
        unawaited(widget.controller.liveStreamDocRef.update({
          FirebaseConst.battleType: BattleType.initiate.value,
          FirebaseConst.type: LivestreamType.livestream.value,
          FirebaseConst.battleEndedAt: null,
        }));
        widget.controller.startMinViewerTimeoutCheck();
      } else {
        currentSecLeft.value--;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    currentSecLeft.close(); // Free Rx memory
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: whitePure(context).withValues(alpha: .1),
      ),
      child: Row(
        spacing: 5,
        children: [
          Expanded(
            child: Text(
              isBattleView
                  ? LKey.youWillBeSentBackToMainView.tr
                  : LKey.streamEndedMinUserDescription.trParams({
                      'viewers_count':
                          widget.controller.minViewersThreshold.toString()
                    }),
              style: TextStyleCustom.outFitLight300(
                  color: whitePure(context), fontSize: 17),
            ),
          ),
          Obx(
            () => Text(
              Duration(seconds: currentSecLeft.value).printDuration,
              style: TextStyleCustom.unboundedMedium500(
                color: whitePure(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
