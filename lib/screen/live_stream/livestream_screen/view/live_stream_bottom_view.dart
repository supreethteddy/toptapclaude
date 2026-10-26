// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/black_gradient_shadow.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/config/deepar/local_deepar_filters.dart';
import 'package:shortzz/config/gifts/premium_gift_animations.dart';
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen_controller.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet.dart';
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
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
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
                        // The comment list sits structurally above the
                        // full-screen double-tap-to-like GestureDetector in
                        // livestream_host_screen.dart/live_stream_audience_
                        // screen.dart (it's part of the control chrome drawn
                        // after/over the video in the Stack, not the video
                        // itself) -- its own ListView claims taps within its
                        // bounds for scrolling, so a double-tap landing on
                        // the comment feed never reached that detector
                        // underneath, even though the semi-transparent
                        // overlay still visually reads as "the video" to a
                        // viewer. This wraps just the comment feed with its
                        // own double-tap handler so liking works there too,
                        // without affecting the real interactive bits below
                        // it (gift/share/more/text field), which aren't
                        // wrapped. globalPosition (not localPosition) because
                        // LiveStreamLikeButton's heart-burst anchor expects
                        // screen coordinates, not this nested widget's own.
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onDoubleTapDown: (details) =>
                              controller.onLikeButtonTap(
                            details.globalPosition,
                            details.globalPosition.dx <
                                MediaQuery.sizeOf(context).width / 2,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            child:
                                LiveStreamCommentView(controller: controller),
                          ),
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
      bool isBattleOn = stream.type == LivestreamType.battle;
      // Viewer-facing PK battle bar: matches the client's TikTok reference
      // (people / team-A gift / team-B gift / share icons beside the
      // comment box) in TopTap's own colors — the base (non-battle) row
      // below is untouched.
      if (isAudience && isBattleOn) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            if (isVisible) const SizedBox(width: 6),
            if (isVisible)
              _BattleViewerActionIcons(
                controller: controller,
                onShareTap: () => _shareStream(context),
              ),
          ],
        );
      }
      // Client reference: once another host/co-host is actually sharing the
      // screen (same-room co-host/guest on stage, or cross-room connected),
      // the message box disappears entirely and only the stage-connection
      // icons stay directly visible -- share/beautify move into the "..."
      // sheet instead of fighting the connection icons for space. The
      // solo-host row below is untouched; this only replaces it once
      // someone else is actually sharing the screen.
      final hasOtherHostOnScreen = !isAudience &&
          (controller.streamViews.length > 1 || stream.opponentRoomId != null);
      if (hasOtherHostOnScreen) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isVisible) _HostLinkAndGuestIcons(controller: controller),
            if (isVisible)
              _buildControlButton(context,
                  icon: Icons.more_vert,
                  onTap: () => _showMoreOptions(context)),
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (isVisible && !isAudience)
            _HostLinkAndGuestIcons(controller: controller),
          if (isVisible && isAudience)
            _buildGuestRequestButton(context, stream),
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
                icon: Icons.more_vert, onTap: () => _showMoreOptions(context)),
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
                    return;
                  }
                  // closeCoHostStream used to fire the instant this was
                  // tapped -- a brush of the thumb while reaching for the
                  // text field or gift icon right next to it could knock a
                  // co-host/guest off stage with no way to undo it. Same
                  // confirm-before-leaving pattern the top-right exit button
                  // already uses (onCloseAudienceBtn), just worded for
                  // stepping down from stage rather than leaving the whole
                  // live.
                  Get.bottomSheet(
                    ConfirmationSheet(
                      title: LKey.leaveStageTitle.tr,
                      description: LKey.leaveStageDescription.tr,
                      onTap: () {
                        Get.back();
                        controller.closeCoHostStream(userId);
                      },
                    ),
                  );
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
                          title: Text(
                              isVideoOn ? 'Turn camera off' : 'Turn camera on'),
                          onTap: () {
                            Get.back();
                            controller.toggleVideo(isVideoOn);
                          },
                        ),
                      ],
                    );
                  }),
                  // Share/Beautify: always shown here too, not just when the
                  // compact "other host on screen" row hides them inline
                  // (see _buildBottomControlsRow) -- one consistent place to
                  // find them in either layout, not a mode-specific item.
                  ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: Text(LKey.share.tr),
                    onTap: () {
                      Get.back();
                      _shareStream(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.face_retouching_natural),
                    title: const Text('Beautify'),
                    onTap: () {
                      Get.back();
                      controller.onBeautifyTap();
                    },
                  ),
                  if (controller.isHost && Platform.isAndroid)
                    ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('Filters'),
                      onTap: () {
                        Get.back();
                        _showLiveFilterSheet(context);
                      },
                    ),
                  // A Moderator with guest-management delegated (client
                  // spec 14.4) gets this entry too -- openMembersSheet()
                  // itself decides which mode of the sheet that opens.
                  if (controller.isHost || controller.canManageGuests)
                    ListTile(
                      leading: const Icon(Icons.groups_outlined),
                      title: Text(LKey.members.tr),
                      onTap: () {
                        Get.back();
                        controller.openMembersSheet();
                      },
                    ),
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
                      final enabled = controller.liveData.value.commentsEnabled;
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
                  // Host-only (client spec 14.5: Moderators must not assign
                  // other Moderators) -- was previously reachable from this
                  // same sheet with no check of its own, relying only on
                  // the sheet's own host-only visibility; explicit now that
                  // a Moderator with guest-management can also open this
                  // sheet via the Members entry above.
                  if (controller.isHost)
                    ListTile(
                      leading: const Icon(Icons.shield_outlined),
                      title: Text(LKey.manageModerators.tr),
                      onTap: () {
                        Get.back();
                        Get.to(() => ManageModeratorsScreen(
                            roomID: controller.liveData.value.roomID ?? ''));
                      },
                    ),
                  if (controller.liveData.value.type != LivestreamType.battle)
                    ListTile(
                      leading: Image.asset(AssetRes.icBattleVs,
                          height: 22, width: 22),
                      title: Text(LKey.findOpponent.tr),
                      onTap: () {
                        Get.back();
                        Get.to(() => FindOpponentScreen(myLive: controller));
                      },
                    ),
                  // Debug-only: no premium gift has a real tbl_gifts row yet, so
                  // there is no real send flow to exercise this overlay through.
                  // Remove once real gifts exist and this can be verified via
                  // an actual send instead.
                  if (kDebugMode)
                    ListTile(
                      leading: const Icon(Icons.movie_filter_outlined),
                      title: const Text('Debug: Test Premium Gift'),
                      onTap: () {
                        Get.back();
                        Get.bottomSheet(
                          Container(
                            color: adaptiveBackground(context),
                            constraints: const BoxConstraints(maxHeight: 500),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                for (final entry in premiumGiftAnimations)
                                  ListTile(
                                    title: Text(entry.name),
                                    subtitle: Text(entry.hasVideo
                                        ? entry.videoUrl
                                        : '(no videoUrl set)'),
                                    onTap: () {
                                      Get.back();
                                      controller.debugTriggerPremiumGift(
                                          entry.giftId);
                                    },
                                  ),
                              ],
                            ),
                          ),
                          isScrollControlled: true,
                        );
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

  /// Same DeepAR filter picker as the pre-LIVE Effects sheet
  /// (create_live_stream_screen_controller.dart's onEffectsTap), reachable
  /// from here while actually LIVE via the "Filters" entry above. Calls the
  /// same (now static) onLiveFilterSelected, so a host who went live with
  /// "None" can turn a filter on mid-stream, and one who went live with a
  /// filter can switch between them -- both go through the fast
  /// switchEffect-only path there once DeepAR is already active, and the
  /// full Zego<->DeepAR camera handoff the first time a filter is picked.
  void _showLiveFilterSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: adaptiveBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Obx(() => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filters',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    CreateLiveStreamScreenController.isDeepArLiveActive.value
                        ? (CreateLiveStreamScreenController
                                .selectedLiveFilter.value.title ??
                            'None')
                        : 'None',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 92,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: CreateLiveStreamScreenController
                          .availableLiveFilters.length,
                      itemBuilder: (context, index) {
                        final filter = CreateLiveStreamScreenController
                            .availableLiveFilters[index];
                        // selectedLiveFilter.value is the single source of
                        // truth regardless of isDeepArLiveActive -- picking
                        // "None" after DeepAR is already active keeps
                        // isDeepArLiveActive true (DeepAR stays in the
                        // pipeline, just rendering the plain camera; see
                        // onLiveFilterSelected's own comment on why), so
                        // that flag alone can't be used to detect "None" is
                        // selected.
                        final isSelected = filter.id ==
                            CreateLiveStreamScreenController
                                .selectedLiveFilter.value.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            onTap: () => CreateLiveStreamScreenController
                                .onLiveFilterSelected(filter),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 56,
                                  width: 56,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.white24,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    color: Colors.white12,
                                  ),
                                  child: _liveFilterThumbnail(filter.image),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    filter.title ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.orange
                                            : Colors.white70,
                                        fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _liveFilterThumbnail(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const Icon(Icons.block, color: Colors.white38, size: 28);
    }
    final uri = Uri.tryParse(imagePath);
    final isNetwork = uri != null && uri.hasScheme && uri.host.isNotEmpty;
    return isNetwork
        ? Image.network(imagePath, fit: BoxFit.cover)
        : Image.asset(imagePath, fit: BoxFit.cover);
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

/// Viewer-facing PK battle bottom bar (client's TikTok reference): people /
/// rose / gift / share, beside the comment box. Team membership is read
/// from the real roster (pkTeamA/BUserIds for a same-room PK Match,
/// both rooms' own getAllUsers for a cross-room battle) instead of
/// assuming exactly one person per side, so this works the same for a 1v1
/// or a 2v2 (or an uneven) match — tapping the gift icon opens a small
/// picker across whichever hosts are actually on either side rather than a
/// single hardcoded recipient. Previously this was two separate red/blue
/// buttons, each hardcoded to users.first/users.last, which only worked
/// for exactly 2 on-stage users and vanished the moment a co-host joined
/// either side.
class _BattleViewerActionIcons extends StatelessWidget {
  final LivestreamScreenController controller;
  final VoidCallback onShareTap;

  const _BattleViewerActionIcons({
    required this.controller,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stream = controller.liveData.value;
      final isNotOnStage = controller.streamViews.firstWhereOrNull(
            (view) => view.streamId == controller.myUserId.toString(),
          ) ==
          null;
      final allUsers = controller.firestoreController.users;
      List<AppUser> teamA;
      List<AppUser> teamB;
      if (stream.opponentRoomId != null) {
        // Cross-room party battle: each side's "team" is that room's own
        // on-stage roster (host + any co-hosts/guests) PLUS, once a Four-
        // person Team PK teammate (client spec Module 6/7) has joined, that
        // teammate's own independently-live room's roster too -- absent for
        // a plain 1v1 match, so teamA/teamB are unchanged from before.
        teamA = [
          ...stream.getAllUsers(allUsers),
          ...?controller.teammateWatch.liveData.value?.getAllUsers(allUsers),
        ];
        teamB = [
          ...?controller.opponentLiveData.value?.getAllUsers(allUsers),
          ...?controller.opponentTeammateWatch.liveData.value
              ?.getAllUsers(allUsers),
        ];
      } else {
        // Same-room PK Match: real team arrays set by _startPkMatch (falls
        // back to [host]/[first co-host] for pre-team-array battle data).
        teamA = controller.pkTeamAUserIds
            .map((id) => allUsers.firstWhereOrNull((u) => u.userId == id))
            .whereType<AppUser>()
            .toList();
        teamB = controller.pkTeamBUserIds
            .map((id) => allUsers.firstWhereOrNull((u) => u.userId == id))
            .whereType<AppUser>()
            .toList();
      }
      final showBattleGift =
          isNotOnStage && (teamA.isNotEmpty || teamB.isNotEmpty);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 37,
            width: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: StyleRes.themeGradient,
              shape: BoxShape.circle,
            ),
            child: GestureDetector(
              onTap: controller.openAudienceSheet,
              child: const Icon(Icons.people, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          // One-tap Rose shortcut (reference's rose icon) -- same send path
          // as the full gift sheet, see sendQuickGift.
          GestureDetector(
            onTap: controller.sendQuickGift,
            child: Container(
              height: 37,
              width: 37,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4D8D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_florist,
                  color: Colors.white, size: 18),
            ),
          ),
          if (showBattleGift) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () =>
                  _openBattleGiftPicker(context, teamA: teamA, teamB: teamB),
              child: Container(
                height: 37,
                width: 37,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF2F56),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onShareTap,
            child: Container(
              height: 37,
              width: 37,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.share_outlined,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 4),
          // Running gift-total for the whole match (reference's "22.2K"
          // next to share) -- pure display, summed from data already
          // streamed for the score bar/top gifters, no new state.
          _GiftTotalCounter(controller: controller),
        ],
      );
    });
  }

  /// Exactly one possible recipient across both sides (e.g. the opponent
  /// room hasn't finished loading yet) -- send straight to them, no picker
  /// needed. Otherwise show both sides' rosters so the viewer picks who on
  /// whichever team gets the gift; this is what makes a 2+-member team
  /// (2v2) work at all, since the old code could only ever address a
  /// single hardcoded user per side.
  void _openBattleGiftPicker(
    BuildContext context, {
    required List<AppUser> teamA,
    required List<AppUser> teamB,
  }) {
    if (teamA.length + teamB.length == 1) {
      final onlyTeamA = teamA.isNotEmpty;
      controller.onGiftTap(
        GiftType.battle,
        battleViewType: onlyTeamA ? BattleView.red : BattleView.blue,
        users: [onlyTeamA ? teamA.first : teamB.first],
      );
      return;
    }
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send gift to',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (teamA.isNotEmpty)
                _teamRecipientRow(context, teamA, BattleView.red),
              if (teamA.isNotEmpty && teamB.isNotEmpty)
                const SizedBox(height: 18),
              if (teamB.isNotEmpty)
                _teamRecipientRow(context, teamB, BattleView.blue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamRecipientRow(
      BuildContext context, List<AppUser> team, BattleView side) {
    final tint = side == BattleView.red
        ? ColorRes.likeRed
        : ColorRes.battleProgressColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final user in team)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () {
                Get.back();
                controller.onGiftTap(GiftType.battle,
                    battleViewType: side, users: [user]);
              },
              child: Column(
                children: [
                  CustomImage(
                    size: const Size(48, 48),
                    image: user.profile?.addBaseURL(),
                    fullName: user.fullname,
                    strokeColor: tint,
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 56,
                    child: Text(
                      user.username ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sum of every participant's totalCoin (totalBattleCoin + liveCoin,
/// LivestreamUserState.totalCoin) on both sides of the match -- a running
/// total gift value for the whole PK battle, matching the reference's
/// counter next to the share icon.
class _GiftTotalCounter extends StatelessWidget {
  final LivestreamScreenController controller;

  const _GiftTotalCounter({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mine = controller.liveUsersStates
          .fold<int>(0, (sum, state) => sum + state.totalCoin);
      final opponent = controller.opponentUserStates
          .fold<int>(0, (sum, state) => sum + state.totalCoin);
      final total = mine + opponent;
      if (total <= 0) return const SizedBox();
      return Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          total.numberFormat,
          style: TextStyleCustom.outFitSemiBold600(
              color: Colors.white, fontSize: 12),
        ),
      );
    });
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
            child: const Icon(Icons.people, color: Color(0xFF25F4EE), size: 18),
          );
        }),
        // Co-Host connection controls: only appear once connected to
        // another independently-live host. Connecting never auto-starts a
        // battle (see acceptCoHostConnectInvite) -- "Play PK Match" is the
        // separate, explicit step, and it still requires the other
        // connected host's accept (requestPkMatch/acceptPkMatch), it
        // doesn't start the battle by itself.
        Obx(() {
          final stream = controller.liveData.value;
          if (stream.opponentRoomId == null) return const SizedBox();
          final isBattling = stream.battleType == BattleType.waiting ||
              stream.battleType == BattleType.running;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isBattling) ...[
                const SizedBox(width: 6),
                // Icon-only, matching this row's other circular buttons --
                // the earlier wide text pill ("Play PK Match") plus the
                // exit button plus the comment field's own prefix/suffix
                // icons together didn't fit this row's actual width on a
                // real phone, overflowing into the comment box next to it.
                // Tooltip carries the label for discoverability instead.
                Tooltip(
                  message: LKey.playPkMatch.tr,
                  child: GestureDetector(
                    onTap: controller.requestPkMatch,
                    child: Container(
                      height: 37,
                      width: 37,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFE2C55), Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.bolt, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                // Four-person Team PK (client spec Module 6): only once
                // connected and not already teamed up with someone -- team
                // roster is fixed before a battle starts, same as the Play
                // PK Match button it sits next to.
                if (stream.coHostTeammateRoomId == null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: LKey.addTeammate.tr,
                    child: GestureDetector(
                      onTap: () => Get.to(() => FindOpponentScreen(
                          myLive: controller, isTeammateInvite: true)),
                      child: Container(
                        height: 37,
                        width: 37,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.person_add_alt_1,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ],
            ],
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
      controller
          .showSnackBar(controller.pkIneligibleMessage(eligibility.reason));
      return;
    }
    if (eligibility.mode == PkMode.twoVsTwo) {
      controller.showSnackBar(LKey.twoVsTwoMatchComingSoon.tr);
      return;
    }
    controller.openPkMatchSetupSheet();
  }
}
