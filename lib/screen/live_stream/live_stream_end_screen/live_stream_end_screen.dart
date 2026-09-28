import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/live_stream_end_screen/widget/livestream_summary.dart';

class LiveStreamEndScreen extends StatelessWidget {
  final LivestreamUserState? userState;
  final bool isHost;
  final int viewers;
  final List<LivestreamUserState> mostWatchedUsers;

  const LiveStreamEndScreen(
      {super.key,
      required this.userState,
      required this.isHost,
      required this.viewers,
      this.mostWatchedUsers = const []});

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
