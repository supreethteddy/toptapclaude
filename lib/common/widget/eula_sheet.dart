import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/widget/eula_policy_for_apple.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/utilities/theme_res.dart';

class EulaSheet extends StatelessWidget {
  const EulaSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
          top: AppBar().preferredSize.height * 2),
      decoration: ShapeDecoration(
          color: scaffoldBackgroundColor(context),
          shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.vertical(
                  top: SmoothRadius(
                      cornerRadius: 30,
                      cornerSmoothing: 1)))),
      child: Column(
        children: [
          const Expanded(
              child: ClipRRect(
                  borderRadius: SmoothBorderRadius.vertical(
                      top: SmoothRadius(
                          cornerRadius: 30,
                          cornerSmoothing: 1)),
                  child: EulaPolicyForApple())),
          SafeArea(
            top: false,
            child: TextButtonCustom(
              onTap: () {
                SessionManager.instance
                    .setOpenEulaSheet(false);
                Get.back();
              },
              title: LKey.accept.tr,
              titleColor: whitePure(context),
              backgroundColor: themeColor(context),
              borderSide: BorderSide(
                  color: whitePure(context), width: 1),
            ),
          )
        ],
      ),
    );
  }
}
