import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/theme_res.dart';

class CustomBackButton extends StatelessWidget {
  final String? image;
  final double? height;
  final double? width;
  final VoidCallback? onTap;
  final Color? color;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;

  const CustomBackButton(
      {super.key,
      this.height = 20,
      this.width = 20,
      this.onTap,
      this.color,
      this.alignment,
      this.image,
      this.padding});

  @override
  Widget build(BuildContext context) {
    void handleBackTap() {
      if (onTap != null) {
        onTap!.call();
        return;
      }

      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        navigator.maybePop();
        return;
      }

      if (Get.key.currentState?.canPop() ?? false) {
        Get.back();
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handleBackTap,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(3.0),
          child: Image.asset(
            image ?? AssetRes.icBackArrow,
            height: height,
            width: width,
            color: color ?? textDarkGrey(context),
            alignment: alignment ?? Alignment.center,
          ),
        ),
      ),
    );
  }
}
