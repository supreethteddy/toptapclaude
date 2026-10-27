import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/live_stream_end_screen/widget/livestream_summary.dart';

class LiveStreamEndScreen extends StatelessWidget {
  final LivestreamUserState? userState;
  final bool isHost;
  final int viewers;
  final List<LivestreamUserState> mostWatchedUsers;
  final int peakViewers;
  final int shareCount;
  final List<(AppUser?, int)> topGifters;
  final String? leagueDivision;
  final int? leagueRank;

  const LiveStreamEndScreen(
      {super.key,
      required this.userState,
      required this.isHost,
      required this.viewers,
      this.mostWatchedUsers = const [],
      this.peakViewers = 0,
      this.shareCount = 0,
      this.topGifters = const [],
      this.leagueDivision,
      this.leagueRank});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        body: LiveStreamSummary(
          userState: userState,
          isHost: isHost,
          viewers: viewers,
          mostWatchedUsers: mostWatchedUsers,
          peakViewers: peakViewers,
          shareCount: shareCount,
          topGifters: topGifters,
          leagueDivision: leagueDivision,
          leagueRank: leagueRank,
          onGoHomeTap: _goHome,
        ),
      ),
    );
  }

  /// Leaves the "Stream Ended" summary and returns to the home dashboard.
  /// Pops every route left on top of the first (dashboard) route so the host
  /// is never trapped on this screen and can start a new live afterwards.
  void _goHome() {
    if (Get.isBottomSheetOpen ?? false) Get.back();
    if (Get.isDialogOpen ?? false) Get.back();
    Get.until((route) => route.isFirst);
  }
}
