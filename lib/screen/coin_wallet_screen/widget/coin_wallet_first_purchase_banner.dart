import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:shortzz/screen/recharge_screen/recharge_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// "First Coin purchase offer" promo banner. Only shown while
/// [CoinWalletScreenController.isEligibleForFirstPurchaseOffer] is true -
/// see that getter for why it's derived from the existing lifetime-purchased
/// counter rather than a dedicated backend flag.
class CoinWalletFirstPurchaseBanner extends StatelessWidget {
  final CoinWalletScreenController controller;

  const CoinWalletFirstPurchaseBanner({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isEligibleForFirstPurchaseOffer) {
        return const SizedBox.shrink();
      }
      return InkWell(
        onTap: () => Get.to(() => const RechargeScreen()),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 15),
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            gradient: StyleRes.themeGradient,
            shape: SmoothRectangleBorder(
              borderRadius:
                  SmoothBorderRadius(cornerRadius: 16, cornerSmoothing: 1),
            ),
          ),
          child: Row(
            children: [
              Image.asset(AssetRes.icCoin, width: 40, height: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(LKey.firstCoinPurchaseOffer.tr,
                        style: TextStyleCustom.unboundedMedium500(
                            color: whitePure(context), fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(LKey.firstCoinPurchaseOfferDescription.tr,
                        style: TextStyleCustom.outFitRegular400(
                            color: whitePure(context).withValues(alpha: .9),
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
