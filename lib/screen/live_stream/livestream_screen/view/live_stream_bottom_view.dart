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
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart';
import 'package:shortzz/screen/live_stream/manage_moderators_screen/manage_moderators_screen.dart';
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
            // Floating Right Controls (positioned absolutely)
            Obx(
              () => Positioned(
                right: 15,
                bottom: 80,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  offset: controller.isRightControlsVisible.value
                      ? Offset.zero
                      : const Offset(0, 1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:
                        controller.isRightControlsVisible.value ? 1.0 : 0.0,
                    child: controller.isRightControlsVisible.value
                        ? _buildRightControls(context)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
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
                      child: _buildHostControls(),
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
          // Share (Figma "Live1"): moved out of the collapsible right-controls
          // panel so it's always visible, far right of the bottom bar. Same
          // `_shareStream` logic as before, just a white outline icon here.
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
        ],
      );
    });
  }

  /// Audience: "join as guest" request (client item L-13). Hidden while a
  /// PK battle runs, when the host restricted joining, or once we are already
  /// a co-host.
  Widget _buildGuestRequestButton(BuildContext context, Livestream stream) {
    final isBattleOn = stream.type == LivestreamType.battle;
    final isCoHost = (stream.coHostIds ?? []).contains(controller.myUserId);
    if (isBattleOn || stream.isRestrictToJoin != 0 || isCoHost) {
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

  Widget _buildHostControls() {
    return Obx(() {
      int? userId = controller.myUser.value?.id;
      LivestreamUserState? state = controller.liveUsersStates.firstWhereOrNull(
        (element) => element.userId == userId,
      );
      final isHostOrCoHost = state?.type == LivestreamUserType.host ||
          state?.type == LivestreamUserType.coHost;
      bool isMute = state?.isMuted ?? false;
      bool isVideoOn = state?.isVideoOn ?? false;
      Livestream stream = controller.liveData.value;
      bool isBattleRunning = stream.battleType == BattleType.running;
      if (!isHostOrCoHost) return const SizedBox();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (LivestreamUserType.coHost == state?.type &&
                stream.type == LivestreamType.livestream)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  if (isBattleRunning) {
                    controller.showSnackBar('Cannot leave during battle');
                  } else {
                    controller.closeCoHostStream(userId);
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              onPressed: controller.toggleFlipCamera,
            ),
            IconButton(
              icon: Icon(
                isMute ? Icons.mic_off : Icons.mic,
                color: isMute ? Colors.red : Colors.white,
              ),
              onPressed: () => controller.toggleMic(isMute),
            ),
            IconButton(
              icon: Icon(
                isVideoOn ? Icons.videocam : Icons.videocam_off,
                color: isVideoOn ? Colors.white : Colors.red,
              ),
              onPressed: () => controller.toggleVideo(isVideoOn),
            ),
            if (state?.type == LivestreamUserType.host)
              _GuestsButton(controller: controller),
            if (state?.type == LivestreamUserType.host &&
                stream.type != LivestreamType.battle &&
                stream.battleType == BattleType.initiate)
              _PkButton(controller: controller),
            if (state?.type == LivestreamUserType.host)
              IconButton(
                tooltip: 'About Me',
                icon: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                ),
                onPressed: controller.showAboutMeDialog,
              ),
            if (state?.type == LivestreamUserType.host)
              IconButton(
                tooltip: stream.commentsEnabled
                    ? 'Turn comments off'
                    : 'Turn comments on',
                icon: Icon(
                  stream.commentsEnabled
                      ? Icons.mode_comment_outlined
                      : Icons.comments_disabled_outlined,
                  color: stream.commentsEnabled ? Colors.white : Colors.red,
                ),
                onPressed: controller.toggleCommentsEnabled,
              ),
          ],
        ),
      );
    });
  }

  Widget _buildRightControls(BuildContext context) {
    // Share used to live here too (Figma "Live1" moved it to the always
    // visible bottom bar, see `_buildBottomControlsRow`), so this collapsible
    // panel now only holds the beauty filter shortcut plus host-only extras.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildControlButton(
          context,
          icon: Icons.face_retouching_natural,
          onTap: () {
            _showBeautyFilters(context);
          },
        ),
        if (!isAudience) ...[
          const SizedBox(height: 30),
          _buildControlButton(
            context,
            icon: Icons.more_vert,
            onTap: () {
              _showMoreOptions(context);
            },
          ),
        ],
      ],
    );
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
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
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  void _showBeautyFilters(BuildContext context) {
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
              'Beauty Filters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                _buildFilterOption('Smooth', Icons.blur_on, () {
                  Get.back();
                }),
                _buildFilterOption('Brighten', Icons.brightness_high, () {
                  Get.back();
                }),
                _buildFilterOption('Eyes', Icons.remove_red_eye, () {
                  Get.back();
                }),
                _buildFilterOption('Face', Icons.face, () {
                  Get.back();
                }),
                _buildFilterOption('Lips', Icons.favorite, () {
                  Get.back();
                }),
                _buildFilterOption('Reset', Icons.refresh, () {
                  Get.back();
                }),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorRes.themeColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Get.back();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
/// "Find Opponent" item already opens), friends jumps straight to inviting a
/// viewer on screen as a guest (the Invited tab of the same MembersSheet
/// _GuestsButton below opens, just defaulted to a different tab).
class _HostLinkAndGuestIcons extends StatelessWidget {
  final LivestreamScreenController controller;

  const _HostLinkAndGuestIcons({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleIconButton(
          onTap: () => Get.to(() => FindOpponentScreen(myLive: controller)),
          child: Image.asset(AssetRes.icLink,
              color: Colors.white, height: 18, width: 18),
        ),
        const SizedBox(width: 6),
        Obx(() {
          final pending = controller.invitedList.length;
          return _circleIconButton(
            onTap: () => controller.openMembersSheet(
              initialTab: MembersSheet.tabInvited,
            ),
            badgeCount: pending,
            child: const Icon(Icons.people, color: Colors.white, size: 18),
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

/// Guest requests / invites entry point (client items L-01, L-13).
class _GuestsButton extends StatelessWidget {
  final LivestreamScreenController controller;

  const _GuestsButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pending = controller.requestList.length;
      return IconButton(
        tooltip: LKey.guests.tr,
        onPressed: () => controller.openMembersSheet(
          initialTab: MembersSheet.tabRequests,
        ),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.person_add_alt_1, color: Colors.white),
            if (pending > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: ColorRes.likeRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pending',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// PK battle entry point (client item L-12). Always visible for the host;
/// explains what is missing when no guest is on screen yet.
class _PkButton extends StatelessWidget {
  final LivestreamScreenController controller;

  const _PkButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ready = controller.canStartBattle;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: controller.startBattle,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: ready
                  ? const LinearGradient(
                      colors: [Color(0xFFFF3D6E), Color(0xFF7C4DFF)])
                  : null,
              color: ready ? null : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AssetRes.icBattleVs,
                    height: 14, width: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  LKey.pk.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
