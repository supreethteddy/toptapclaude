import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/haptic_manager.dart';
import 'package:toptap/utilities/style_res.dart';
import 'package:toptap/utilities/theme_res.dart';

class CustomToggle extends StatelessWidget {
  final RxBool isOn;
  final Function(bool value)? onChanged;

  const CustomToggle(
      {super.key, required this.isOn, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Obx(() => InkWell(
          onTap: onChanged != null
              ? () {
                  onChanged?.call(!isOn.value);
                  HapticManager.shared.light();
                }
              : null,
          child: AnimatedContainer(
            height: 25,
            width: 37,
            decoration: ShapeDecoration(
                shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                        cornerRadius: 30)),
                gradient: isOn.value
                    ? StyleRes.themeGradient
                    : StyleRes.textLightGreyGradient()),
            alignment: isOn.value
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(
                horizontal: 3.5, vertical: 3),
            duration: const Duration(milliseconds: 300),
            child: Container(
                width: 20,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: whitePure(context))),
          ),
        ));
  }
}
