import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Grid of purchasable coin packages. Tapping a cell only selects/highlights
/// it (via [CoinWalletScreenController.selectPlan]) - the actual purchase is
/// triggered from the single bottom button in `RechargeBottomBar`.
///
/// NOTE on the "Custom" amount tile from the Figma design: native in-app
/// purchases (via the `in_app_purchase` package / App Store / Play Store)
/// only support fixed, pre-registered SKUs. `Setting.coinPackages` /
/// `CoinPackage` only define fixed `coinAmount` + `appstoreProductId` /
/// `playStoreProductId` pairs matched against store `ProductDetails` - there
/// is no "custom amount" SKU or any backend support for charging an
/// arbitrary amount through `SubscriptionManager`/`GiftWalletService`. Since
/// there is no working way to actually charge a custom amount through the
/// existing purchase pipeline, a "Custom" tile is intentionally omitted here
/// rather than shipping a button that cannot function.
class RechargePackageGrid extends StatelessWidget {
  final CoinWalletScreenController controller;

  const RechargePackageGrid({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.coinPlans.isEmpty) {
        return const SizedBox.shrink();
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 20),
        itemCount: controller.coinPlans.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 112,
        ),
        itemBuilder: (context, index) {
          CoinPlan data = controller.coinPlans[index];
          return Obx(() {
            bool isSelected = controller.selectedPlan.value == data;
            return InkWell(
              onTap: () => controller.selectPlan(data),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: ShapeDecoration(
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                            cornerRadius: 12, cornerSmoothing: 1),
                        side: BorderSide(
                          color: isSelected
                              ? themeAccentSolid(context)
                              : textLightGrey(context).withValues(alpha: .2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      color: isSelected
                          ? themeAccentSolid(context).withValues(alpha: .08)
                          : bgLightGrey(context),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(AssetRes.icCoin, width: 32, height: 32),
                        const SizedBox(height: 6),
                        Text('${data.coin} ${LKey.coins.tr}',
                            style: TextStyleCustom.unboundedMedium500(
                                color: textDarkGrey(context), fontSize: 13),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 2),
                        Text(data.priceString,
                            style: TextStyleCustom.outFitRegular400(
                                color: textLightGrey(context), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Image.asset(AssetRes.icCheckCircle,
                          width: 20, height: 20),
                    ),
                ],
              ),
            );
          });
        },
      );
    });
  }
}
