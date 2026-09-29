import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/custom_search_text_field.dart';
import 'package:shortzz/common/widget/custom_tab_switcher.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream_comment.dart';
import 'package:shortzz/model/livestream/livestream_user_state.dart';
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

  void onSelectedTab(int index) {
    selectedTab.value = index;
    pageController.animateToPage(index,
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
    return Container(
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
                ],
                onTap: onSelectedTab,
                selectedIndex: selectedTab,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: bgLightGrey(context),
                selectedFontColor: themeAccentSolid(context),
              );
            }),
          Obx(
            () => selectedTab.value == MembersSheet.tabCoHosts
                ? const SizedBox()
                : CustomSearchTextField(
                    backgroundColor: bgLightGrey(context),
                    onChanged: (value) => query.value = value,
                  ),
          ),
          Expanded(
            child: !widget.isHost ? _buildAudienceList() : _buildHostPages(),
          ),
        ],
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

  /// Invited viewers on top, then every other viewer with an Invite button so
  /// the host can collect guests from this one place.
  Widget _buildInvitedPage() {
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
        return TextBorderButton(
          text: LKey.invite.tr,
          onTap: () => controller.onInvite(user, isInvited: false),
        );
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
