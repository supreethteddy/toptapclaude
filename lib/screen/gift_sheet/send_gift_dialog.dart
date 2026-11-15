import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/widget/custom_image.dart';
import 'package:toptap/common/widget/gradient_text.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/general/settings_model.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/style_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class SendGiftDialog extends StatefulWidget {
  final Gift gift;

  const SendGiftDialog({super.key, required this.gift});

  @override
  State<SendGiftDialog> createState() => _SendGiftDialogState();
}

class _SendGiftDialogState extends State<SendGiftDialog> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: AppRes.giftDialogDismissTime), () {
      Get.back();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: whitePure(context),
      shape: RoundedRectangleBorder(borderRadius: SmoothBorderRadius(cornerRadius: 20)),
      alignment: const Alignment(0, 0.4),
      child: AspectRatio(
        aspectRatio: 1.8,
        child: Container(
          decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(borderRadius: SmoothBorderRadius(cornerRadius: 20)),
              color: whitePure(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomImage(
                  image: widget.gift.image?.addBaseURL(),
                  size: const Size(90, 90),
                  radius: 0),
              Text(LKey.yourGiftHasBeenSent.tr,
                  style: TextStyleCustom.outFitRegular400(
                      fontSize: 15, color: textLightGrey(context))),
              GradientText(LKey.successfully.tr,
                  gradient: StyleRes.themeGradient,
                  style: TextStyleCustom.unboundedSemiBold600(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
