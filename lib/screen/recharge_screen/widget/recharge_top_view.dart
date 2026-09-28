import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/widget/custom_back_button.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Header for the Recharge screen: back button + title, and the current
/// coin balance shown just below it.
class RechargeTopView extends StatelessWidget {
  final CoinWalletScreenController controller;

  const RechargeTopView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
      child: Column(
        children: [
          Row(
            children: [
              CustomBackButton(color: textDarkGrey(context)),
              Expanded(
                child: Text(
                  LKey.recharge.tr,
                  textAlign: TextAlign.center,
                  style: TextStyleCustom.unboundedMedium500(
                      color: textDarkGrey(context), fontSize: 18),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 14, cornerSmoothing: 1),
                side: BorderSide(
                  color: textLightGrey(context).withValues(alpha: .2),
                ),
              ),
              color: bgLightGrey(context),
            ),
            child: Row(
              children: [
                Image.asset(AssetRes.icCoin, width: 32, height: 32),
                const SizedBox(width: 10),
                Obx(() {
                  User? user = controller.myUser.value;
                  return Text(
                    (user?.coinWallet?.toInt() ?? 0).numberFormat,
                    style: TextStyleCustom.unboundedExtraBold800(
                        color: textDarkGrey(context), fontSize: 22),
                  );
                }),
                const SizedBox(width: 8),
                Text(LKey.balance.tr,
                    style: TextStyleCustom.outFitLight300(
                        color: textLightGrey(context), fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
