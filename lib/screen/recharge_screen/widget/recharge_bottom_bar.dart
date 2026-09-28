import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';

/// Single bottom "Recharge" button. Purchases whichever package is
/// currently selected in the grid above, via the existing
/// `CoinWalletScreenController.onPurchase` flow (unchanged verification
/// pipeline). Shows a message instead of purchasing when nothing is
/// selected yet.
class RechargeBottomBar extends StatelessWidget {
  final CoinWalletScreenController controller;

  const RechargeBottomBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
        child: Obx(() {
          CoinPlan? selected = controller.selectedPlan.value;
          return Opacity(
            opacity: selected == null ? 0.5 : 1,
            child: TextButtonCustom(
              title: selected == null
                  ? LKey.recharge.tr
                  : '${LKey.recharge.tr} • ${selected.priceString}',
              btnHeight: 54,
              horizontalMargin: 0,
              onTap: () {
                if (selected == null) {
                  controller.showSnackBar(LKey.selectACoinPackage.tr);
                  return;
                }
                controller.onPurchase(selected);
              },
            ),
          );
        }),
      ),
    );
  }
}
