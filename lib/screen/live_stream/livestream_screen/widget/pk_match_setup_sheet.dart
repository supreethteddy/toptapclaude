import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/bottom_sheet_top_view.dart';
import 'package:shortzz/common/widget/custom_divider.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// 1v1 PK Match setup: pick which gifts count toward the score, see the
/// (admin-configured, read-only here) round duration, and send the
/// invitation. There is no opponent picker — PkEligibility only offers this
/// sheet when exactly one co-host is eligible, so they already are the
/// opponent.
class PkMatchSetupSheet extends StatefulWidget {
  final String roomID;

  const PkMatchSetupSheet({super.key, required this.roomID});

  @override
  State<PkMatchSetupSheet> createState() => _PkMatchSetupSheetState();
}

class _PkMatchSetupSheetState extends State<PkMatchSetupSheet> {
  late final controller =
      Get.find<LivestreamScreenController>(tag: widget.roomID);
  final RxBool allGiftsCount = true.obs;
  final RxSet<int> selectedGiftIds = <int>{}.obs;
  final RxBool isSending = false.obs;

  AppUser? get _host => controller.liveData.value
      .getHostUser(controller.firestoreController.users);

  AppUser? get _opponent {
    final hostId = controller.liveData.value.hostId;
    final opponentId = controller.pkMatchEligibility.eligibleIds
        .firstWhereOrNull((id) => id != hostId);
    if (opponentId == null) return null;
    return controller.firestoreController.users
        .firstWhereOrNull((user) => user.userId == opponentId);
  }

  // Closes itself the moment the invite this sheet sent actually turns into
  // a running match — there is nothing left for the sheet to do once
  // BattleView takes over the screen.
  late final Worker _matchStartedWorker;

  @override
  void initState() {
    super.initState();
    _matchStartedWorker = ever<Livestream>(controller.liveData, (stream) {
      if (stream.type == LivestreamType.battle &&
          stream.battleType == BattleType.waiting &&
          mounted) {
        Get.back();
      }
    });
  }

  @override
  void dispose() {
    _matchStartedWorker.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (isSending.value) return;
    isSending.value = true;
    final giftIds = allGiftsCount.value ? null : selectedGiftIds.toList();
    await controller.sendPkMatchInvite(eligibleGiftIds: giftIds);
    isSending.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: whitePure(context),
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final isPending =
              controller.liveData.value.pkInviteFromId == controller.myUserId;
          return isPending ? _buildPendingView(context) : _buildConfigureView(context);
        }),
      ),
    );
  }

  Widget _buildConfigureView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BottomSheetTopView(
            title: LKey.pkMatchSetupTitle.tr, sideBtnVisibility: false),
        _buildMatchup(context),
        const SizedBox(height: 10),
        _buildDurationRow(context),
        const CustomDivider(),
        Flexible(child: _buildGiftsSection(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Obx(
            () => Opacity(
              opacity: isSending.value ? 0.6 : 1,
              child: TextButtonCustom(
                onTap: _send,
                title: LKey.sendMatchInvitation.tr,
                horizontalMargin: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shown in place of the configure form once the invite is out — the host
  /// just watches the same VS card and can pull it back with Withdraw;
  /// declining/expiring on the other end flips this back to the configure
  /// view on its own (pkInviteFromId clears), ready to send again.
  Widget _buildPendingView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BottomSheetTopView(
            title: LKey.pkMatchInviteTitle.tr, sideBtnVisibility: false),
        _buildMatchup(context),
        const SizedBox(height: 16),
        Text(
          LKey.pkMatchWaitingForResponse
              .trParams({'name': _opponent?.username ?? ''}),
          style: TextStyleCustom.outFitRegular400(
              color: textLightGrey(context), fontSize: 14),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: TextButtonCustom(
            onTap: () => controller.declinePkMatchInvite(),
            title: LKey.withdraw.tr,
            horizontalMargin: 0,
            backgroundColor: bgMediumGrey(context),
            titleColor: textDarkGrey(context),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMatchup(BuildContext context) {
    const avatarSize = 72.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildPlayerColumn(context, _host, avatarSize)),
          Text('VS',
              style: TextStyleCustom.unboundedSemiBold600(
                  color: textDarkGrey(context), fontSize: 16)),
          Expanded(child: _buildPlayerColumn(context, _opponent, avatarSize)),
        ],
      ),
    );
  }

  Widget _buildPlayerColumn(BuildContext context, AppUser? user, double size) {
    return Column(
      children: [
        CustomImage(
          size: Size(size, size),
          image: user?.profile?.addBaseURL(),
          fullName: user?.fullname,
        ),
        const SizedBox(height: 6),
        FullNameWithBlueTick(
          username: user?.username,
          isVerify: user?.isVerify,
          fontSize: 13,
        ),
      ],
    );
  }

  Widget _buildDurationRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(LKey.pkMatchDuration.tr,
              style: TextStyleCustom.outFitRegular400(
                  color: textLightGrey(context), fontSize: 14)),
          Text('${controller.pkMatchDurationMinutes} min',
              style: TextStyleCustom.outFitMedium500(
                  color: textDarkGrey(context), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildGiftsSection(BuildContext context) {
    final gifts = controller.gifts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 15, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(LKey.pkMatchEligibleGifts.tr,
                  style: TextStyleCustom.outFitRegular400(
                      color: textLightGrey(context), fontSize: 14)),
              Row(
                children: [
                  Text(LKey.pkMatchAllGiftsCount.tr,
                      style: TextStyleCustom.outFitRegular400(
                          color: textDarkGrey(context), fontSize: 13)),
                  Obx(
                    () => Switch.adaptive(
                      value: allGiftsCount.value,
                      activeThumbColor: themeAccentSolid(context),
                      onChanged: (value) => allGiftsCount.value = value,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Obx(
          () => Opacity(
            opacity: allGiftsCount.value ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: allGiftsCount.value,
              child: SizedBox(
                height: 160,
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 10),
                  itemCount: gifts.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisExtent: 90,
                          crossAxisSpacing: 5,
                          mainAxisSpacing: 5),
                  itemBuilder: (context, index) =>
                      _buildGiftTile(context, gifts[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGiftTile(BuildContext context, Gift gift) {
    final giftId = gift.id;
    return Obx(() {
      final isSelected =
          giftId != null && selectedGiftIds.contains(giftId);
      return InkWell(
        onTap: giftId == null
            ? null
            : () {
                if (isSelected) {
                  selectedGiftIds.remove(giftId);
                } else {
                  selectedGiftIds.add(giftId);
                }
              },
        child: Container(
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
              borderRadius:
                  SmoothBorderRadius(cornerRadius: 8, cornerSmoothing: 1),
              side: BorderSide(
                  color: isSelected
                      ? themeAccentSolid(context)
                      : bgGrey(context),
                  width: isSelected ? 2 : 1),
            ),
            color: bgLightGrey(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomImage(
                  image: gift.image?.addBaseURL(),
                  size: const Size(38, 38),
                  radius: 0),
              const SizedBox(height: 4),
              Text((gift.coinPrice ?? 0).numberFormat,
                  style: TextStyleCustom.outFitMedium500(
                      fontSize: 11, color: textLightGrey(context))),
            ],
          ),
        ),
      );
    });
  }
}
