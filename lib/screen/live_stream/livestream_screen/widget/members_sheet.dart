import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/custom_search_text_field.dart';
import 'package:shortzz/common/widget/custom_tab_switcher.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/live_invite.dart';
import 'package:shortzz/model/livestream/livestream_comment.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/invite_candidates_controller.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Host tabs: Requests (viewers asking to join), Invited (viewers the host
/// invited + viewers that can still be invited), Co-hosts (on screen now).
/// The old "Audience" tab was removed; the viewer list lives behind the eye
/// icon in the top bar.
class MembersSheet extends StatefulWidget {
  final bool isHost;
  final int initialTab;
  final String roomID;

  static const int tabRequests = 0;
  static const int tabInvited = 1;
  static const int tabCoHosts = 2;
  static const int tabGuests = 3;

  const MembersSheet(
      {super.key,
      required this.isHost,
      this.initialTab = 0,
      required this.roomID});

  @override
  State<MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<MembersSheet> {
  late final controller =
      Get.find<LivestreamScreenController>(tag: widget.roomID);
  late final PageController pageController =
      PageController(initialPage: widget.initialTab);
  late final RxInt selectedTab = widget.initialTab.obs;
  final RxString query = ''.obs;

  // Invited page's own secondary switcher: who is in the room already vs.
  // who can be reached out-of-room (Friends / Recommended).
  static const int _subTabInRoom = 0;
  final RxInt invitedSubTab = _subTabInRoom.obs;
  late final PageController invitedSubPageController = PageController();
  late final InviteCandidatesController inviteCandidates;
  late final String _inviteCandidatesTag =
      'invite_candidates_${widget.roomID}';

  @override
  void initState() {
    super.initState();
    inviteCandidates = Get.put(
      InviteCandidatesController(),
      tag: _inviteCandidatesTag,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    invitedSubPageController.dispose();
    Get.delete<InviteCandidatesController>(tag: _inviteCandidatesTag);
    super.dispose();
  }

  void onSelectedTab(int index) {
    selectedTab.value = index;
    pageController.animateToPage(index,
        duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  void onSelectedInvitedSubTab(int index) {
    invitedSubTab.value = index;
    invitedSubPageController.animateToPage(index,
        duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  List<LivestreamUserState> _filter(List<LivestreamUserState> source) {
    final q = query.value.trim();
    if (q.isEmpty) return source;
    return source.search(q, (p0) {
      return p0.getUser(controller.firestoreController.users)?.username ?? '';
    }, (p1) {
      return p1.getUser(controller.firestoreController.users)?.fullname ?? '';
    });
  }

  AppUser? _userOf(LivestreamUserState state) => controller
      .firestoreController.users
      .firstWhereOrNull((element) => element.userId == state.userId);

  @override
  Widget build(BuildContext context) {
    // This sheet's own background is always pure white (see `whitePure`
    // usage below) regardless of the app's light/dark theme, but
    // `NoDataView`'s empty-state text and `MemberProfileCard`'s full-name
    // line both color themselves via `textLightGrey`/`textDarkGrey`, which
    // follow the ambient theme — in dark mode that resolves to white,
    // rendering invisible against this always-white sheet (seen as a
    // completely blank Invited/Co-hosts list). Pin the text theme to the
    // light-mode values here so everything stays legible in both modes.
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.copyWith(
              titleSmall: const TextStyle(color: ColorRes.likeRed),
              titleMedium: const TextStyle(color: ColorRes.green1),
            ),
      ),
      child: Container(
        margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
        decoration: ShapeDecoration(
          color: whitePure(context),
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
                top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)),
          ),
        ),
        child: Column(
          children: [
            BottomSheetTopView(
                title: widget.isHost ? LKey.guests.tr : LKey.members.tr,
                sideBtnVisibility: false),
            if (widget.isHost)
              Obx(() {
                final pending = controller.requestList.length;
                return CustomTabSwitcher(
                  items: [
                    pending > 0
                        ? '${LKey.requests.tr} ($pending)'
                        : LKey.requests.tr,
                    LKey.invited.tr,
                    LKey.coHosts.tr,
                    LKey.guests.tr,
                  ],
                  onTap: onSelectedTab,
                  selectedIndex: selectedTab,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: bgLightGrey(context),
                  selectedFontColor: themeAccentSolid(context),
                );
              }),
            Obx(
              () => selectedTab.value >= MembersSheet.tabCoHosts
                  ? const SizedBox()
                  : CustomSearchTextField(
                      backgroundColor: bgLightGrey(context),
                      onChanged: (value) {
                        query.value = value;
                        inviteCandidates.onSearchChanged(value);
                      },
                    ),
            ),
            Expanded(
              child: !widget.isHost ? _buildAudienceList() : _buildHostPages(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceList() {
    return Obx(() {
      final items = _filter(controller.audienceMemberList);
      return NoDataView(
        showShow: items.isEmpty,
        title: LKey.userListEmptyTitle.tr,
        description: LKey.userListEmptyDescription.tr,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final state = items[index];
            return MemberProfileCard(
                user: _userOf(state), widget: const SizedBox());
          },
        ),
      );
    });
  }

  Widget _buildHostPages() {
    return PageView(
      controller: pageController,
      onPageChanged: (value) => selectedTab.value = value,
      children: [
        _buildRequestsPage(),
        _buildInvitedPage(),
        _buildCoHostsPage(),
        _buildGuestsPage(),
      ],
    );
  }

  Widget _buildRequestsPage() {
    return Obx(() {
      final items = _filter(controller.requestList);
      return NoDataView(
        showShow: items.isEmpty,
        title: LKey.requestTitle.tr,
        description: LKey.requestDescription.tr,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final state = items[index];
            final user = _userOf(state);
            return MemberProfileCard(
              user: user,
              widget: _buildActionWidget(state, user),
            );
          },
        ),
      );
    });
  }

  /// In room / Friends / Recommended: the in-room list reaches viewers
  /// already watching, the other two reach people who are not in the room at
  /// all (out-of-room `LiveInvite` + FCM nudge, see
  /// LivestreamScreenController.inviteOutOfRoom).
  Widget _buildInvitedPage() {
    return Column(
      children: [
        CustomTabSwitcher(
          items: [LKey.inRoom.tr, LKey.friends.tr, LKey.recommended.tr],
          onTap: onSelectedInvitedSubTab,
          selectedIndex: invitedSubTab,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          backgroundColor: bgLightGrey(context),
          selectedFontColor: themeAccentSolid(context),
        ),
        Expanded(
          child: PageView(
            controller: invitedSubPageController,
            onPageChanged: (value) => invitedSubTab.value = value,
            children: [
              _buildInRoomInviteList(),
              _buildCandidatesList(
                isFriends: true,
                loading: inviteCandidates.isLoadingFriends,
              ),
              _buildCandidatesList(
                isFriends: false,
                loading: inviteCandidates.isLoadingRecommended,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Invited viewers on top, then every other viewer with an Invite button so
  /// the host can collect guests from this one place.
  Widget _buildInRoomInviteList() {
    return Obx(() {
      final invited = _filter(controller.invitedList);
      final invitable = _filter(controller.audienceList);
      if (invited.isEmpty && invitable.isEmpty) {
        return NoDataView(
          showShow: true,
          title: LKey.invitedListEmptyTitle.tr,
          description: LKey.invitedListEmptyDescription.tr,
          child: const SizedBox(),
        );
      }
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          if (invited.isNotEmpty) ...[
            _SectionLabel(LKey.invited.tr),
            for (final state in invited)
              MemberProfileCard(
                user: _userOf(state),
                widget: _buildActionWidget(state, _userOf(state)),
              ),
          ],
          _SectionLabel(LKey.inviteViewers.tr),
          if (invitable.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                LKey.noViewersToInvite.tr,
                textAlign: TextAlign.center,
                style: TextStyleCustom.outFitLight300(
                    color: textLightGrey(context), fontSize: 14),
              ),
            ),
          for (final state in invitable)
            MemberProfileCard(
              user: _userOf(state),
              widget: _buildActionWidget(state, _userOf(state)),
            ),
        ],
      );
    });
  }

  /// Shared by the Friends and Recommended pages — only the source list and
  /// loading flag differ.
  Widget _buildCandidatesList({required bool isFriends, required RxBool loading}) {
    return Obx(() {
      final items = isFriends
          ? inviteCandidates.friendsVisible
          : inviteCandidates.recommendedVisible;
      final isBusy = loading.value ||
          (!isFriends && inviteCandidates.isSearching.value);
      if (items.isEmpty) {
        return NoDataView(
          showShow: !isBusy,
          title: LKey.noInviteCandidatesTitle.tr,
          description: LKey.noInviteCandidates.tr,
          child: const SizedBox(),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) => _buildCandidateRow(items[index]),
      );
    });
  }

  Widget _buildCandidateRow(User user) {
    return Obx(() {
      // Touch liveData/outgoingInvites so this rebuilds as seats/status change.
      controller.liveData.value;
      final invite =
          user.id == null ? null : controller.outgoingInviteFor(user.id!);
      return MemberProfileCard(
        user: user.appUser,
        widget: _buildCandidateAction(user, invite),
      );
    });
  }

  Widget _buildCandidateAction(User user, LiveInvite? invite) {
    if (invite != null) {
      switch (invite.status) {
        case LiveInviteStatus.pending:
          return TextBorderButton(
            text: LKey.invitedEllipsis.tr,
            onTap: () => controller.cancelOutOfRoomInvite(invite),
          );
        case LiveInviteStatus.accepted:
          return TextBorderButton(text: LKey.inRoom.tr, textOpacity: .5);
        case LiveInviteStatus.declined:
          return TextBorderButton(
            text: LKey.declinedTapToReinvite.tr,
            onTap: () => controller.inviteOutOfRoom(user, invite.role),
          );
        case LiveInviteStatus.expired:
        case LiveInviteStatus.cancelled:
        case LiveInviteStatus.seatsFull:
          break; // Treat as a clean slate: fall through to fresh invite buttons.
      }
    }
    final coHostSeat = controller.hasSeatFor(LivestreamUserType.coHost);
    final guestSeat = controller.hasSeatFor(LivestreamUserType.guest);
    if (!coHostSeat && !guestSeat) {
      return TextBorderButton(text: LKey.seatsFullShort.tr, textOpacity: .4);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: coHostSeat ? 1 : .4,
          child: TextBorderButton(
            text: LKey.coHosts.tr,
            onTap: coHostSeat
                ? () => controller.inviteOutOfRoom(
                    user, LivestreamUserType.coHost)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Opacity(
          opacity: guestSeat ? 1 : .4,
          child: TextBorderButton(
            text: LKey.guest.tr,
            onTap: guestSeat
                ? () =>
                    controller.inviteOutOfRoom(user, LivestreamUserType.guest)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCoHostsPage() {
    return Obx(() {
      final items = controller.coHostList;
      return NoDataView(
        showShow: items.isEmpty,
        title: LKey.coHostListEmptyTitle.tr,
        description: LKey.coHostListEmptyDescription.tr,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final state = items[index];
            final user = _userOf(state);
            return MemberProfileCard(
              user: user,
              widget: _buildActionWidget(state, user),
            );
          },
        ),
      );
    });
  }

  Widget _buildGuestsPage() {
    return Obx(() {
      final items = controller.guestList;
      return NoDataView(
        showShow: items.isEmpty,
        title: LKey.guestListEmptyTitle.tr,
        description: LKey.guestListEmptyDescription.tr,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final state = items[index];
            final user = _userOf(state);
            return MemberProfileCard(
              user: user,
              widget: _buildActionWidget(state, user),
            );
          },
        ),
      );
    });
  }

  /// Two invite buttons because the two roles are different seats with
  /// different caps: Co-host Mode (PK-eligible, 4 in frame) vs Guest Call.
  /// A button is disabled - not hidden - when that role's seats are full so
  /// the host can see why.
  Widget _buildInviteButtons(AppUser? user) {
    return Obx(() {
      // Touch liveData so this rebuilds as seats are taken/freed.
      controller.liveData.value;
      final coHostSeat = controller.hasSeatFor(LivestreamUserType.coHost);
      final guestSeat = controller.hasSeatFor(LivestreamUserType.guest);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: coHostSeat ? 1 : .4,
            child: TextBorderButton(
              text: LKey.coHosts.tr,
              onTap: () => controller.onInvite(user,
                  isInvited: false, role: LivestreamUserType.coHost),
            ),
          ),
          const SizedBox(width: 6),
          Opacity(
            opacity: guestSeat ? 1 : .4,
            child: TextBorderButton(
              text: LKey.guest.tr,
              onTap: () => controller.onInvite(user,
                  isInvited: false, role: LivestreamUserType.guest),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildActionWidget(LivestreamUserState state, AppUser? user) {
    if (!widget.isHost) return const SizedBox();
    switch (state.type) {
      case LivestreamUserType.requested:
        return Row(
          children: [
            _buildActionBtn(AssetRes.icCheck, ColorRes.green, () async {
              Get.back();
              await controller.acceptJoinRequest(user);
            }),
            _buildActionBtn(AssetRes.icClose1, ColorRes.likeRed, () {
              controller.onRequestRefuse(user,
                  type: LivestreamCommentType.request);
            }),
          ],
        );
      case LivestreamUserType.audience:
        return _buildInviteButtons(user);
      case LivestreamUserType.invited:
        return TextBorderButton(
          text: LKey.cancel.tr,
          onTap: () => controller.onInvite(user, isInvited: true),
        );
      case LivestreamUserType.coHost:
        return Row(
          children: [
            _buildActionBtn(
              state.isVideoOn ? AssetRes.icVideoCamera : AssetRes.icVideoOff,
              textLightGrey(context),
              () => controller.coHostVideoToggle(state),
            ),
            _buildActionBtn(
              state.isMuted ? AssetRes.icMicOff : AssetRes.icMicrophone,
              textLightGrey(context),
              () => controller.coHostAudioToggle(state),
            ),
            _buildActionBtn(AssetRes.icDelete1, ColorRes.likeRed,
                () => controller.coHostDelete(state)),
          ],
        );
      case LivestreamUserType.guest:
        // Same moderation as a co-host, plus an explicit "promote" so a
        // guest can only ever become PK-eligible by a deliberate host action.
        return Row(
          children: [
            _buildActionBtn(
              state.isVideoOn ? AssetRes.icVideoCamera : AssetRes.icVideoOff,
              textLightGrey(context),
              () => controller.coHostVideoToggle(state),
            ),
            _buildActionBtn(
              state.isMuted ? AssetRes.icMicOff : AssetRes.icMicrophone,
              textLightGrey(context),
              () => controller.coHostAudioToggle(state),
            ),
            IconButton(
              tooltip: LKey.promoteToCoHost.tr,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(Icons.upgrade, color: themeAccentSolid(context)),
              onPressed: () => controller.promoteGuestToCoHost(state),
            ),
            _buildActionBtn(AssetRes.icDelete1, ColorRes.likeRed,
                () => controller.coHostDelete(state)),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildActionBtn(String asset, Color color, [VoidCallback? onTap]) {
    return BorderRoundedButton(
      image: asset,
      color: color,
      onTap: onTap,
      padding: 5,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyleCustom.outFitMedium500(
                color: textLightGrey(context), fontSize: 12)
            .copyWith(letterSpacing: 1.5),
      ),
    );
  }
}

class MemberProfileCard extends StatelessWidget {
  final Widget widget;
  final AppUser? user;

  const MemberProfileCard(
      {super.key, required this.widget, required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              CustomImage(
                  size: const Size(40, 40),
                  image: user?.profile?.addBaseURL(),
                  fullName: user?.fullname),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FullNameWithBlueTick(
                      username: user?.username,
                      isVerify: user?.isVerify,
                      fontSize: 13,
                      iconSize: 18,
                    ),
                    Text(user?.fullname ?? '',
                        style: TextStyleCustom.outFitLight300(
                            color: textLightGrey(context)))
                  ],
                ),
              ),
              widget
            ],
          ),
          const SizedBox(height: 10),
          const CustomDivider()
        ],
      ),
    );
  }
}

class BorderRoundedButton extends StatelessWidget {
  final String image;
  final Color color;
  final VoidCallback? onTap;
  final double? padding;
  final double? width;
  final double? height;
  final Color? bgColor;

  const BorderRoundedButton(
      {super.key,
      required this.image,
      required this.color,
      this.onTap,
      this.padding,
      this.width,
      this.height,
      this.bgColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height ?? 34,
        width: width ?? 34,
        padding: EdgeInsets.all(padding ?? 0),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: color)),
        alignment: Alignment.center,
        child: Image.asset(image, color: color, width: 24, height: 24),
      ),
    );
  }
}

class TextBorderButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double? textOpacity;

  const TextBorderButton(
      {super.key, required this.text, this.onTap, this.textOpacity});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 32,
        width: 100,
        decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 8, cornerSmoothing: 1),
                side: BorderSide(color: bgGrey(context)))),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyleCustom.outFitRegular400(
              color: textLightGrey(context),
              fontSize: 15,
              opacity: textOpacity),
        ),
      ),
    );
  }
}

class Values {
  String image;
  Color color;
  double padding;

  Values(this.image, this.color, {this.padding = 0});
}
