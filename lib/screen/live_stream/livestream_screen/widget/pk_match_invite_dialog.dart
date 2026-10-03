import 'package:flutter/material.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// The invitee's side of a same-room PK Match invitation: the same VS card
/// shown to the host while they wait (PkMatchSetupSheet's pending view), not
/// a plain text alert. Also doubles as the rematch invite dialog — same
/// shape, just asked again after a match ends.
class PkMatchInviteDialog extends StatelessWidget {
  final AppUser? host;
  final AppUser? me;
  final int durationMinutes;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const PkMatchInviteDialog({
    super.key,
    required this.host,
    required this.me,
    required this.durationMinutes,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: whitePure(context),
      shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(cornerRadius: 24, cornerSmoothing: 1)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(LKey.pkMatchInviteTitle.tr,
                style: TextStyleCustom.unboundedSemiBold600(
                    color: textDarkGrey(context), fontSize: 17)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _playerColumn(context, host)),
                Text('VS',
                    style: TextStyleCustom.unboundedSemiBold600(
                        color: textDarkGrey(context), fontSize: 16)),
                Expanded(child: _playerColumn(context, me)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              LKey.pkMatchInviteDescription.trParams({
                'name': host?.username ?? '',
                'duration': '$durationMinutes',
              }),
              textAlign: TextAlign.center,
              style: TextStyleCustom.outFitRegular400(
                  color: textLightGrey(context), fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButtonCustom(
                    onTap: onDecline,
                    title: LKey.refuse.tr,
                    horizontalMargin: 0,
                    backgroundColor: bgMediumGrey(context),
                    titleColor: textDarkGrey(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButtonCustom(
                    onTap: onAccept,
                    title: LKey.accept.tr,
                    horizontalMargin: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerColumn(BuildContext context, AppUser? user) {
    const avatarSize = 64.0;
    return Column(
      children: [
        CustomImage(
          size: const Size(avatarSize, avatarSize),
          image: user?.profile?.addBaseURL(),
          fullName: user?.fullname,
        ),
        const SizedBox(height: 6),
        FullNameWithBlueTick(
          username: user?.username,
          isVerify: user?.isVerify,
          fontSize: 12,
        ),
      ],
    );
  }
}
