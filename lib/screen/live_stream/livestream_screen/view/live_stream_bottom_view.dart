// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/black_gradient_shadow.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/find_opponent_screen/find_opponent_screen.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/view/livestream_comment_view.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_stream_text_field.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/livestream_exist_message_bar.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/fan_club_widgets.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/gift_goals_panel.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_poll_widgets.dart';
import 'package:shortzz/screen/live_stream/manage_moderators_screen/manage_moderators_screen.dart';
import 'package:shortzz/model/livestream/pk_eligibility.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveStreamBottomView extends StatelessWidget {
  final bool isAudience;
  final LivestreamScreenController controller;

  const LiveStreamBottomView({
    Key? key,
    this.isAudience = false,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: Get.height / 3,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            const BlackGradientShadow(height: 200),
            // Samsung One UI's gesture-nav bar intercepts touches in a taller
            // zone near the physical bottom edge than stock Android, which
            // silently swallowed taps on the host controls row below (flip
            // camera/mic/video/PK/etc, all confirmed clickable on other
            // phones) since nothing here previously inset for the bottom
            // system gesture area. SafeArea pushes just this control overlay
            // up above that zone; the video background elsewhere stays
            // edge-to-edge.
            SafeArea(
              top: false,
              child: Column(
              children: [
                // Comments Section
                Expanded(
                  child: Obx(() {
                    bool isVisible = controller.isViewVisible.value;
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isVisible ? 1 : 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        child: LiveStreamCommentView(controller: controller),
                      ),
                    );
                  }),
                ),
                // Bottom Controls Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 2,
                  ),
                  child: _buildBottomControlsRow(context),
                ),
                // Host Controls (if user is host/co-host). These must follow
                // the same visibility state as the rest of the LIVE chrome;
                // otherwise invisible camera/mic buttons can still be tapped.
                Obx(() {
                  final isVisible = controller.isViewVisible.value;
                  return IgnorePointer(
                    ignoring: !isVisible,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isVisible ? 1 : 0,
                      child: _buildHostControls(context),
                    ),
                  );
                }),
                // Exit Message Bar
                Obx(() {
                  Livestream stream = controller.liveData.value;
                  if ((stream.type == LivestreamType.battle &&
                          stream.battleType == BattleType.end) ||
                      controller.isMinViewerTimeout.value) {
                    return LivestreamExistMessageBar(
                      controller: controller,
                      stream: stream,
                    );
                  } else {
                    return const SizedBox();
                  }
                }),
                const SizedBox(height: 0),
              ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlsRow(BuildContext context) {
    return Obx(() {
      bool isVisible = controller.isViewVisible.value;
      Livestream stream = controller.liveData.value;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isVisible && !isAudience) _HostLinkAndGuestIcons(controller: controller),
          if (isVisible && isAudience) _buildGuestRequestButton(context, stream),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isVisible ? 1 : 0,
              alwaysIncludeSemantics: false,
              child: IgnorePointer(
                ignoring: !isVisible,
                child: LiveStreamTextFieldView(
                  isAudience: isAudience,
                  controller: controller,
                ),
              ),
            ),
          ),
          // Share, Beautify, More: client reference shows all three in this
          // same bottom row (not a separately floating column) — these two
          // used to live in a collapsible panel positioned on the right
          // edge mid-screen; moved in here to match.
          if (isVisible) const SizedBox(width: 8),
          if (isVisible)
            GestureDetector(
              onTap: () => _shareStream(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.share_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          if (isVisible) const SizedBox(width: 8),
          if (isVisible)
            _buildControlButton(context,
                icon: Icons.face_retouching_natural,
                onTap: controller.onBeautifyTap),
          if (isVisible) const SizedBox(width: 8),
          if (isVisible && !isAudience)
            _buildControlButton(context,
                icon: Icons.more_vert,
                onTap: () => _showMoreOptions(context)),
        ],
      );
    });
  }

  /// Audience: "join as guest" request (client item L-13). Hidden while a
  /// PK battle runs, when the host restricted joining, or once we are already
  /// a co-host.
  Widget _buildGuestRequestButton(BuildContext context, Livestream stream) {
    final isBattleOn = stream.type == LivestreamType.battle;
    // Already on stage (co-host or guest), battle running, host restricted
    // joining, or the admin switched guest requests off — no request pill.
    final isOnStage = stream.isOnStage(controller.myUserId);
    if (isBattleOn ||
        stream.isRestrictToJoin != 0 ||
        isOnStage ||
        !controller.guestRequestsEnabled) {
      return const SizedBox.shrink();
    }
    final myState = controller.liveUsersStates
        .firstWhereOrNull((e) => e.userId == controller.myUserId);
    final requested = myState?.type == LivestreamUserType.requested;
    // Figma "Live1": pink/purple tint, matching the PK button's gradient
    // colors used elsewhere in this file for consistency.
    const guestRequestTint = Color(0xFF7C4DFF);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => controller.onVideoRequestSend(stream),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: requested
                ? Colors.white.withOpacity(0.25)
                : guestRequestTint.withOpacity(0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: requested
                  ? Colors.white.withOpacity(0.3)
                  : guestRequestTint.withOpacity(0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AssetRes.icVideoRequest,
                  height: 16, width: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                requested ? LKey.requested.tr : LKey.guest.tr,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Client reference for the base (pre-invite) screen shows only the link,
  // guest, share, beautify and more icons — no flip/mic/video and no second
  // guest icon. Flip/mic/video moved into the "..." sheet (_showMoreOptions)
  // alongside About Me and the comments toggle; the Guests button here was
  // a duplicate of the bottom-left guest icon (_HostLinkAndGuestIcons, now
  // opens GoLiveWithGuestsSheet) and is gone. Only Leave (co-host/guest)
  // and the PK Match button remain — both are stage-appropriate (leave
  // only makes sense once you're on stage; PK only once there's someone to
  // challenge, already gated by PkEligibility).
  Widget _buildHostControls(BuildContext context) {
    return Obx(() {
      int? userId = controller.myUser.value?.id;
      LivestreamUserState? state = controller.liveUsersStates.firstWhereOrNull(
        (element) => element.userId == userId,
      );
      final isHostOrCoHost = state?.type == LivestreamUserType.host ||
          state?.type == LivestreamUserType.coHost ||
          state?.type == LivestreamUserType.guest;
      Livestream stream = controller.liveData.value;
      // A same-room PK Match has no countdown (client spec) and so never
      // passes through BattleType.running on its way from waiting to end —
      // it stays in `waiting` for the whole active match. Treat both as
      // "can't leave" so this guard still protects it.
      bool isBattleRunning = stream.battleType == BattleType.waiting ||
          stream.battleType == BattleType.running;
      if (!isHostOrCoHost) return const SizedBox();
      final showLeave = (LivestreamUserType.coHost == state?.type ||
              LivestreamUserType.guest == state?.type) &&
          stream.type == LivestreamType.livestream;
      final showPkMatch = state?.type == LivestreamUserType.host &&
          stream.type != LivestreamType.battle;
      if (!showLeave && !showPkMatch) return const SizedBox();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLeave)
              _buildControlButton(
                context,
                icon: Icons.close,
                iconColor: Colors.red,
                onTap: () {
                  if (isBattleRunning) {
                    controller.showSnackBar('Cannot leave during battle');
                  } else {
                    controller.closeCoHostStream(userId);
                  }
                },
              ),
            if (showPkMatch) _PkMatchButton(controller: controller),
          ],
        ),
      );
    });
  }

  void _showMoreOptions(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: adaptiveBackground(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          // Flip/mic/video joined the previously-shorter list of options
          // here and overflowed it on shorter screens — now capped and
          // scrollable instead of a fixed-height Column.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: Get.height * .7),
            child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flip camera / mic / camera toggle — moved here from the
              // always-visible row to match the client's minimal bottom
              // bar (link, guest, share, beautify, more only). Only shown
              // to whoever is actually on stage; this sheet itself is only
              // reachable via the more icon, already host/co-host/guest
              // only (see _buildBottomControlsRow).
              Obx(() {
                final userId = controller.myUser.value?.id;
                final state = controller.liveUsersStates
                    .firstWhereOrNull((e) => e.userId == userId);
                final isMute = state?.isMuted ?? false;
                final isVideoOn = state?.isVideoOn ?? false;
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.flip_camera_ios),
                      title: const Text('Flip camera'),
                      onTap: () {
                        Get.back();
                        controller.toggleFlipCamera();
                      },
                    ),
                    ListTile(
                      leading: Icon(isMute ? Icons.mic_off : Icons.mic),
                      title: Text(isMute ? 'Unmute' : 'Mute'),
                      onTap: () {
                        Get.back();
                        controller.toggleMic(isMute);
                      },
                    ),
                    ListTile(
                      leading: Icon(
                          isVideoOn ? Icons.videocam : Icons.videocam_off),
                      title:
                          Text(isVideoOn ? 'Turn camera off' : 'Turn camera on'),
                      onTap: () {
                        Get.back();
                        controller.toggleVideo(isVideoOn);
                      },
                    ),
                  ],
                );
              }),
              if (controller.isHost) ...[
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('About Me'),
                  onTap: () {
                    Get.back();
                    controller.showAboutMeDialog();
                  },
                ),
                Obx(() {
                  final enabled =
                      controller.liveData.value.commentsEnabled;
                  return ListTile(
                    leading: Icon(enabled
                        ? Icons.mode_comment_outlined
                        : Icons.comments_disabled_outlined),
                    title: Text(
                        enabled ? 'Turn comments off' : 'Turn comments on'),
                    onTap: () {
                      Get.back();
                      controller.toggleCommentsEnabled();
                    },
                  );
                }),
              ],
              ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: Text(LKey.giftGoals.tr),
                onTap: () {
                  Get.back();
                  Get.bottomSheet(
                    GiftGoalsPanel(controller: controller),
                    isScrollControlled: true,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.poll_outlined),
                title: Text(LKey.interact.tr),
                onTap: () {
                  Get.back();
                  Get.bottomSheet(
                    LivePollSheet(controller: controller),
                    isScrollControlled: true,
                  );
                },
              ),
              if (controller.liveData.value.hasFanClub == true)
                ListTile(
                  leading: const Icon(Icons.diamond_outlined),
                  title: Text(LKey.fanClub.tr),
                  onTap: () {
                    Get.back();
                    Get.bottomSheet(
                      FanClubMembersSheet(controller: controller),
                      isScrollControlled: true,
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(LKey.manageModerators.tr),
                onTap: () {
                  Get.back();
                  Get.to(() => const ManageModeratorsScreen());
                },
              ),
              if (controller.liveData.value.type != LivestreamType.battle)
                ListTile(
                  leading: Image.asset(AssetRes.icBattleVs, height: 22, width: 22),
                  title: Text(LKey.findOpponent.tr),
                  onTap: () {
                    Get.back();
                    Get.to(() => FindOpponentScreen(myLive: controller));
                  },
                ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  void _shareStream(BuildContext context) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Stream',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption('Share', Icons.ios_share, () {
                  Get.back();
                  controller.shareLiveStream();
                }),
                _buildShareOption('Copy Invite', Icons.copy, () {
                  Get.back();
                  controller.copyLiveStreamInvite();
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}


/// TikTok's bottom-left chain-link + friends icon pair: chain opens the
/// cross-room "link with another host" flow (same screen the "..." menu's
/// "Find Opponent" item already opens), friends opens GoLiveWithGuestsSheet
/// (stage 3 — invite guest) — the sole guest-invite entry point now.
class _HostLinkAndGuestIcons extends StatelessWidget {
  final LivestreamScreenController controller;

  const _HostLinkAndGuestIcons({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tinted pink/cyan to match the two-tone "connect" icons TikTok
        // uses for its left-side PK-match / co-host entry points — every
        // other icon in this bar stays plain white, same as TikTok's own
        // right-side icons.
        _circleIconButton(
          onTap: () => Get.to(() => FindOpponentScreen(myLive: controller)),
          child: Image.asset(AssetRes.icLink,
              color: const Color(0xFFFE2C55), height: 18, width: 18),
        ),
        const SizedBox(width: 6),
        Obx(() {
          final pending =
              controller.invitedList.length + controller.requestList.length;
          return _circleIconButton(
            onTap: controller.openGoLiveWithGuestsSheet,
            badgeCount: pending,
            child:
                const Icon(Icons.people, color: Color(0xFF25F4EE), size: 18),
          );
        }),
      ],
    );
  }

  Widget _circleIconButton({
    required VoidCallback onTap,
    required Widget child,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: child,
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: ColorRes.likeRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// PK Match entry point: visible only for the host and only while a 1v1 or
/// 2v2 match is actually possible (see PkEligibility). A 2v2 match is
/// recognised but not launchable yet — the setup sheet/arena for it ship in
/// a later update, so tapping it says so rather than opening anything.
class _PkMatchButton extends StatelessWidget {
  final LivestreamScreenController controller;

  const _PkMatchButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stream = controller.liveData.value;
      final eligibility = controller.pkMatchEligibility;
      // Nobody to challenge at all - don't clutter the controls with a
      // button that can only ever explain why it's disabled.
      if (eligibility.reason == PkIneligibleReason.hostAlone) {
        return const SizedBox();
      }
      final isPending = stream.pkInviteFromId == controller.myUserId;
      final isReady = eligibility.isAvailable && !isPending;
      final label = eligibility.mode == PkMode.twoVsTwo
          ? LKey.twoVsTwoMatch.tr
          : LKey.oneVsOneMatch.tr;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: isPending ? null : () => _onTap(eligibility),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: isReady
                  ? const LinearGradient(
                      colors: [Color(0xFFFF3D6E), Color(0xFF7C4DFF)])
                  : null,
              color: isReady ? null : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AssetRes.icBattleVs,
                    height: 14, width: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _onTap(PkEligibility eligibility) {
    if (!eligibility.isAvailable) {
      controller.showSnackBar(controller.pkIneligibleMessage(eligibility.reason));
      return;
    }
    if (eligibility.mode == PkMode.twoVsTwo) {
      controller.showSnackBar(LKey.twoVsTwoMatchComingSoon.tr);
      return;
    }
    controller.openPkMatchSetupSheet();
  }
}

