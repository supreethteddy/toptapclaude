import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream_comment.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/invite_candidates_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/widget/members_sheet.dart'
    show MemberProfileCard;
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Stage-3 guest invite entry point (client's 5-stage breakdown: setup →
/// live → invite guest → battle → back to live). Matches the client's
/// TikTok reference exactly: just two sections — viewers already watching,
/// and friends who aren't — each with a single solid "Invite" button,
/// instead of the older Requests/Invited/Co-hosts/Guests tabbed
/// MembersSheet (still reachable from the "..." menu for anyone who needs
/// the separate Guest-role invite or wants to manage/remove people already
/// on stage).
///
/// Invites sent from here default to the Co-host role: the client's own
/// stage 3 → stage 4 narrative is that whoever joins here is who gets
/// invited to battle next, and only co-hosts are PK-eligible (the client's
/// earlier binding Co-host vs Guest Call clarification).
class GoLiveWithGuestsSheet extends StatefulWidget {
  final String roomID;

  const GoLiveWithGuestsSheet({super.key, required this.roomID});

  @override
  State<GoLiveWithGuestsSheet> createState() => _GoLiveWithGuestsSheetState();
}

class _GoLiveWithGuestsSheetState extends State<GoLiveWithGuestsSheet> {
  late final controller =
      Get.find<LivestreamScreenController>(tag: widget.roomID);
  late final InviteCandidatesController inviteCandidates;
  late final String _tag = 'go_live_guests_${widget.roomID}';

  @override
  void initState() {
    super.initState();
    inviteCandidates = Get.put(InviteCandidatesController(), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<InviteCandidatesController>(tag: _tag);
    super.dispose();
  }

  AppUser? _userOf(LivestreamUserState state) => controller
      .firestoreController.users
      .firstWhereOrNull((e) => e.userId == state.userId);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Get.height * .75,
      decoration: ShapeDecoration(
        color: whitePure(context),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            BottomSheetTopView(
                title: LKey.goLiveWithGuests.tr, sideBtnVisibility: false),
            Expanded(
              child: Obx(() {
                final requests = controller.requestList;
                final invited = controller.invitedList;
                final invitable = controller.audienceList;
                // Anyone already in the room in any capacity (watching,
                // invited, requested, on stage) shouldn't also show up as
                // someone to invite from the Friends list.
                final inRoomIds =
                    controller.liveUsersStates.map((s) => s.userId).toSet();
                final friends = inviteCandidates.friends
                    .where((user) => !inRoomIds.contains(user.id))
                    .toList();
                return ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    if (requests.isNotEmpty) ...[
                      _sectionLabel(context, LKey.requests.tr),
                      for (final state in requests)
                        MemberProfileCard(
                          user: _userOf(state),
                          widget: _requestActions(_userOf(state)),
                        ),
                    ],
                    _sectionLabel(context, LKey.viewers.tr),
                    if (invited.isEmpty && invitable.isEmpty)
                      _emptyRow(context, LKey.noViewersToInvite.tr)
                    else ...[
                      for (final state in invited)
                        MemberProfileCard(
                          user: _userOf(state),
                          widget: _InviteButton(
                            label: LKey.invited.tr,
                            filled: false,
                            onTap: () => controller.onInvite(_userOf(state),
                                isInvited: true),
                          ),
                        ),
                      for (final state in invitable)
                        MemberProfileCard(
                          user: _userOf(state),
                          widget: _InviteButton(
                            label: LKey.invite.tr,
                            filled: true,
                            onTap: () => controller.onInvite(_userOf(state),
                                isInvited: false,
                                role: LivestreamUserType.coHost),
                          ),
                        ),
                    ],
                    _sectionLabel(context, LKey.friendsNotWatching.tr),
                    if (inviteCandidates.isLoadingFriends.value)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (friends.isEmpty)
                      _emptyRow(context, LKey.noInviteCandidates.tr)
                    else
                      for (final user in friends)
                        MemberProfileCard(
                          user: user.appUser,
                          widget: _friendInviteButton(user),
                        ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestActions(AppUser? user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () async {
            await controller.acceptJoinRequest(user);
          },
          child: Container(
            height: 32,
            width: 32,
            margin: const EdgeInsets.only(right: 6),
            decoration:
                const BoxDecoration(color: ColorRes.green, shape: BoxShape.circle),
            child: Image.asset(AssetRes.icCheck,
                color: Colors.white, width: 16, height: 16),
          ),
        ),
        InkWell(
          onTap: () => controller.onRequestRefuse(user,
              type: LivestreamCommentType.request),
          child: Container(
            height: 32,
            width: 32,
            decoration: const BoxDecoration(
                color: ColorRes.likeRed, shape: BoxShape.circle),
            child: Image.asset(AssetRes.icClose1,
                color: Colors.white, width: 16, height: 16),
          ),
        ),
      ],
    );
  }

  Widget _friendInviteButton(User user) {
    return Obx(() {
      // Touch liveData/outgoingInvites so this rebuilds as seats/status change.
      controller.liveData.value;
      final invite =
          user.id == null ? null : controller.outgoingInviteFor(user.id!);
      if (invite != null && invite.isPending) {
        return _InviteButton(
          label: LKey.invitedEllipsis.tr,
          filled: false,
          onTap: () => controller.cancelOutOfRoomInvite(invite),
        );
      }
      return _InviteButton(
        label: LKey.invite.tr,
        filled: true,
        onTap: () =>
            controller.inviteOutOfRoom(user, LivestreamUserType.coHost),
      );
    });
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 4),
      child: Text(
        text,
        style: TextStyleCustom.outFitSemiBold600(
            color: textDarkGrey(context), fontSize: 15),
      ),
    );
  }

  Widget _emptyRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyleCustom.outFitLight300(
            color: textLightGrey(context), fontSize: 14),
      ),
    );
  }
}

/// Solid pink "Invite" pill when [filled], a light gray outline pill for
/// states like "Invited…"/"Invited" — matches the client's reference.
class _InviteButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _InviteButton(
      {required this.label, required this.filled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? ColorRes.likeRed : bgLightGrey(context),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyleCustom.outFitSemiBold600(
              color: filled ? Colors.white : textDarkGrey(context),
              fontSize: 13),
        ),
      ),
    );
  }
}
