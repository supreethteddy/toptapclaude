import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/full_name_with_blue_tick.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';

/// Shared "incoming timed invite" dialog: requester's profile, a visible
/// countdown, Accept/Decline. Used for three otherwise-identical flows --
/// the Co-Host connect invite, the "Play PK Match" start request on an
/// already-connected pair, and the 2v2 teammate invite -- so the countdown/
/// expiry behaviour only needs to be built and tested once.
///
/// Call via `Get.dialog(TimedInviteDialog(...), barrierDismissible: false)`;
/// this widget itself has no knowledge of how it was presented.
class TimedInviteDialog extends StatefulWidget {
  final String title;
  final String description;
  final AppUser? requester;
  final int expirySeconds;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const TimedInviteDialog({
    super.key,
    required this.title,
    required this.description,
    required this.requester,
    required this.expirySeconds,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<TimedInviteDialog> createState() => _TimedInviteDialogState();
}

class _TimedInviteDialogState extends State<TimedInviteDialog> {
  late int _secondsLeft = widget.expirySeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        Get.back();
        widget.onDecline();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requester = widget.requester;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (requester != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CustomImage(
                    size: const Size(44, 44),
                    image: requester.profile?.addBaseURL(),
                    fullName: requester.fullname,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FullNameWithBlueTick(
                      username: requester.username,
                      isVerify: requester.isVerify,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          Text(widget.description),
          const SizedBox(height: 10),
          Text(
            '${_secondsLeft}s',
            style: TextStyleCustom.outFitSemiBold600(
                color: ColorRes.likeRed, fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Get.back();
            widget.onDecline();
          },
          child: Text(LKey.refuse.tr),
        ),
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Get.back();
            widget.onAccept();
          },
          child: Text(LKey.accept.tr),
        ),
      ],
    );
  }
}
