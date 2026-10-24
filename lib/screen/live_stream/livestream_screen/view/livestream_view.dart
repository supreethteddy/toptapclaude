import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/audience/widget/live_stream_user_info_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/live_participant_quick_actions_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/reconnecting_placeholder.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LivestreamView extends StatelessWidget {
  final RxList<StreamView> streamViews;
  final LivestreamScreenController controller;

  const LivestreamView(
      {super.key, required this.streamViews, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      Livestream stream = controller.liveData.value;
      List<AppUser> liveUsers = controller.firestoreController.users;
      List<AppUser> allUsers = stream.getAllUsers(liveUsers);

      if (allUsers.isEmpty) {
        return _buildEmptyView();
      }

      // Seats come from who is actually on stage (stageIds: host, then
      // co-hosts, then guests) rather than from who currently has a live
      // Zego stream. A dropped connection used to make that person's tile
      // vanish and the whole grid reflow around the gap — now the seat
      // holds with a reconnecting placeholder (see _resolveSeat) until
      // they're explicitly removed or they leave, which is what actually
      // shrinks stageIds.
      final seats = stream.stageIds
          .map((id) => StageSeat(
                userId: id,
                streamView:
                    streamViews.firstWhereOrNull((v) => v.streamId == '$id'),
                user: liveUsers.firstWhereOrNull((u) => u.userId == id),
              ))
          .toList();

      if (seats.isEmpty) {
        return const LoaderWidget();
      }

      return switch (seats.length) {
        1 =>
          _resolveSeat(seats.first, controller, isNameAndSpeakerVisible: false),
        // 2+ participants (host + co-hosts + Guest Call guests, up to 10):
        // host left, guests in a grid on the right.
        _ => HostAndGuestGridView(controller: controller, seats: seats),
      };
    });
  }

  Widget _buildEmptyView() {
    return Center(
        child: Text(
      'No users in livestream',
      style: TextStyleCustom.unboundedMedium500(color: Colors.white),
    ));
  }
}

/// One seat in the live layout: a host/co-host/guest who is currently
/// either streaming ([streamView] set) or seated but not publishing right
/// now (null — resolved to a [ReconnectingPlaceholder] by [_resolveSeat]).
class StageSeat {
  final int userId;
  final StreamView? streamView;
  final AppUser? user;

  const StageSeat({required this.userId, this.streamView, this.user});
}

Widget _resolveSeat(
  StageSeat seat,
  LivestreamScreenController controller, {
  bool isNameAndSpeakerVisible = true,
}) {
  if (seat.streamView != null) {
    return LiveStreamUserView(
      isNameAndSpeakerVisible: isNameAndSpeakerVisible,
      streamingView: seat.streamView,
      controller: controller,
    );
  }
  if (seat.user != null) {
    return ReconnectingPlaceholder(user: seat.user!);
  }
  return const SizedBox();
}

/// Host-left, guest-grid-right layout for every multi-person stage (2+
/// seats) — matches the client's TikTok reference exactly: the host holds a
/// large tile on the left at full height; guests fill a 2-column grid on
/// the right; any open slots up to [_maxGridSlots] show a "+" the host can
/// tap to invite someone into that spot (plain empty tile for everyone
/// else, who can't invite).
class HostAndGuestGridView extends StatelessWidget {
  final LivestreamScreenController controller;
  final List<StageSeat> seats;

  const HostAndGuestGridView({
    super.key,
    required this.controller,
    required this.seats,
  });

  // Guest Call Mode caps at 1 host + 9 guests (client's binding
  // participant-model clarification); 8 matches the reference's 2x4 grid
  // exactly, and a 9th seated guest just grows the grid to 2x5 rather than
  // being dropped.
  static const int _maxGridSlots = 8;
  static const int _gridColumns = 2;
  static const int _hostFlex = 45;
  static const int _gridFlex = 55;

  // Grid cells are roughly square (reference screenshot), not stretched to
  // fill the whole screen height — height is derived from the cell's own
  // width instead of an Expanded filling whatever room the Stack gives it.
  static const double _cellAspectRatio = 1;
  static const double _cellSpacing = 3;

  @override
  Widget build(BuildContext context) {
    final host = seats.first;
    final guests = seats.skip(1).toList();
    final slotCount =
        guests.length > _maxGridSlots ? guests.length : _maxGridSlots;
    final rows = (slotCount / _gridColumns).ceil();

    return LayoutBuilder(builder: (context, constraints) {
      final gridAreaWidth =
          constraints.maxWidth * _gridFlex / (_hostFlex + _gridFlex);
      final cellWidth =
          (gridAreaWidth - _cellSpacing * (_gridColumns - 1)) / _gridColumns;
      final cellHeight = cellWidth / _cellAspectRatio;
      final blockHeight = rows * cellHeight + _cellSpacing * (rows - 1);

      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          // Clears the header (avatar/name/badges) the same way
          // BattleView's margin does, so a tile's own name/mic overlay
          // never lands underneath the header's eye-count/power icons.
          padding: EdgeInsets.only(top: controller.topHeaderHeight.value),
          child: SizedBox(
            height: blockHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: _hostFlex,
                  child: _resolveSeat(host, controller,
                      isNameAndSpeakerVisible: false),
                ),
                const SizedBox(width: _cellSpacing),
                Expanded(
                  flex: _gridFlex,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int r = 0; r < rows; r++) ...[
                        if (r > 0) const SizedBox(height: _cellSpacing),
                        SizedBox(
                          height: cellHeight,
                          child: Row(
                            children: [
                              for (int c = 0; c < _gridColumns; c++) ...[
                                if (c > 0) const SizedBox(width: _cellSpacing),
                                Expanded(
                                  child:
                                      _gridCell(r * _gridColumns + c, guests),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _gridCell(int index, List<StageSeat> guests) {
    if (index < guests.length) {
      return _resolveSeat(guests[index], controller);
    }
    return _AddGuestSlot(controller: controller);
  }
}

class _AddGuestSlot extends StatelessWidget {
  final LivestreamScreenController controller;

  const _AddGuestSlot({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.isHost) {
      return Container(color: Colors.grey[900]);
    }
    return InkWell(
      onTap: controller.openGoLiveWithGuestsSheet,
      child: Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.add, color: Colors.white54, size: 28),
        ),
      ),
    );
  }
}

class LiveStreamUserView extends StatelessWidget {
  final bool isNameAndSpeakerVisible;
  final AlignmentGeometry? alignment;
  final StreamView? streamingView;
  final LivestreamScreenController controller;

  const LiveStreamUserView({
    super.key,
    this.isNameAndSpeakerVisible = true,
    this.alignment,
    required this.streamingView,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      LivestreamUserState? state = controller.liveUsersStates.firstWhereOrNull(
          (element) =>
              element.userId == int.parse(streamingView?.streamId ?? ''));
      AppUser? liveUser = controller.firestoreController.users.firstWhereOrNull(
          (element) =>
              element.userId == int.parse(streamingView?.streamId ?? ''));

      final tile = _buildTileStack(context, state: state, liveUser: liveUser);

      // Guest-specific gift targeting (client spec, Module 10.2): a viewer
      // (never the host, never on a fellow on-stage participant's own
      // tile) press-and-holds a GUEST's tile for ~1s to open the gift
      // sheet pre-targeted at them instead of the default host recipient.
      final canLongPressForGift = !controller.isHost &&
          liveUser != null &&
          liveUser.userId != controller.myUserId &&
          state?.type == LivestreamUserType.guest;
      if (!canLongPressForGift) return tile;

      return RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 1000)),
            (instance) {
              instance.onLongPress =
                  () => controller.onGuestTileLongPress(liveUser);
            },
          ),
        },
        child: tile,
      );
    });
  }

  Widget _buildTileStack(BuildContext context,
      {required LivestreamUserState? state, required AppUser? liveUser}) {
    return Stack(
      children: [
        if (streamingView != null) streamingView!.streamView,
        if (state?.isVideoOn == false)
          LayoutBuilder(builder: (context, outerConstraints) {
            return Stack(
              children: [
                CustomImage(
                    size: Size(
                        outerConstraints.maxWidth, outerConstraints.maxHeight),
                    image: liveUser?.profile?.addBaseURL(),
                    fullName: liveUser?.fullname,
                    radius: 0),
                LayoutBuilder(
                  builder: (context, constraints) => ClipRect(
                    child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          color: Colors.black.withValues(alpha: .5),
                        )),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: LayoutBuilder(builder: (context, constraints) {
                    double width = ((constraints.maxWidth * 50) / 100);
                    return CustomImage(
                        size: Size(width, width),
                        image: liveUser?.profile?.addBaseURL(),
                        fullName: liveUser?.fullname,
                        strokeWidth: 3);
                  }),
                ),
              ],
            );
          }),
        if (state?.isMuted == true)
          Align(
              alignment: Alignment.center,
              child: Image.asset(
                AssetRes.icMicOff,
                height: 25,
                width: 25,
                color: whitePure(context).withValues(alpha: .6),
              )),
        if (isNameAndSpeakerVisible)
          _buildUserInfoOverlay(context,
              streamView: streamingView!,
              state: state.obs,
              liveUser: liveUser,
              isMuteVisible: liveUser?.userId != controller.myUserId),
        // Quick moderation menu: host-only, and never on the host's own
        // tile (nothing there to moderate). Separate from tapping the
        // name, which still opens the full profile sheet -- this is the
        // fast path for mute/camera/role/remove without leaving the grid.
        if (controller.isHost &&
            liveUser != null &&
            state != null &&
            liveUser.userId != controller.myUserId)
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticManager.shared.light();
                Get.bottomSheet(
                  LiveParticipantQuickActionsSheet(
                      user: liveUser, state: state, controller: controller),
                  isScrollControlled: true,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .35),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.more_vert, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserInfoOverlay(BuildContext context,
      {required AppUser? liveUser,
      required Rx<LivestreamUserState?> state,
      required StreamView? streamView,
      required bool isMuteVisible}) {
    return Align(
      alignment: alignment ?? AlignmentDirectional.topStart,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            if (alignment != null && isMuteVisible)
              MuteUnMuteButton(
                isMute: (streamView?.isMuted ?? false).obs,
                onTap: () => controller.toggleStreamAudio(liveUser?.userId),
              ),
            FullNameWithBlueTick(
              username: liveUser?.username,
              fontColor: whitePure(context),
              fontSize: 12,
              isVerify: liveUser?.isVerify,
              onTap: () => _showUserActionSheet(liveUser!, state),
            ),
            if (alignment == null && isMuteVisible)
              MuteUnMuteButton(
                isMute: (streamView?.isMuted ?? false).obs,
                onTap: () => controller.toggleStreamAudio(liveUser?.userId),
              ),
          ],
        ),
      ),
    );
  }

  void _showUserActionSheet(AppUser user, Rx<LivestreamUserState?> state) {
    Get.bottomSheet(
      LiveStreamUserInfoSheet(
          isAudience: !controller.isHost,
          liveUser: user,
          controller: controller),
      isScrollControlled: true,
    );
  }
}

class MuteUnMuteButton extends StatelessWidget {
  final RxBool isMute;
  final VoidCallback? onTap;

  const MuteUnMuteButton({super.key, required this.isMute, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticManager.shared.light();
        onTap?.call();
      },
      child: Obx(
        () => Image.asset(
          isMute.value ? AssetRes.icSpeakerMute : AssetRes.icSpeaker,
          width: 24,
          height: 24,
          color: whitePure(context).withValues(alpha: .5),
        ),
      ),
    );
  }
}
