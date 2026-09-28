import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:shortzz/screen/recharge_screen/widget/recharge_bottom_bar.dart';
import 'package:shortzz/screen/recharge_screen/widget/recharge_package_grid.dart';
import 'package:shortzz/screen/recharge_screen/widget/recharge_top_view.dart';

/// "Recharge" screen (per Figma): balance at top, a GRID of coin packages
/// (tap to select/highlight), and a single bottom "Recharge" button that
/// purchases whichever package is currently selected.
///
/// This reuses [CoinWalletScreenController] rather than a dedicated
/// controller: it already owns package fetching (`fetchOfferings` /
/// `coinPlans`) and the verified purchase flow (`onPurchase`, which goes
/// through `SubscriptionManager.shared.makePurchaseCustom` and
/// `GiftWalletService.instance.buyCoins`). Duplicating that in a new
/// controller would risk the two screens drifting out of sync, so this
/// screen only adds local selection state (`selectedPlan`) on top of it.
class RechargeScreen extends StatelessWidget {
  const RechargeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The Balance screen (CoinWalletScreen) normally already put this
    // controller before navigating here, so Get.find reuses that instance
    // (keeping balance/coin plans/selection in sync). Falling back to
    // Get.put keeps this screen safe to open on its own too.
    final controller = Get.isRegistered<CoinWalletScreenController>()
        ? Get.find<CoinWalletScreenController>()
        : Get.put(CoinWalletScreenController());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            RechargeTopView(controller: controller),
            Expanded(child: RechargePackageGrid(controller: controller)),
            RechargeBottomBar(controller: controller),
          ],
        ),
      ),
    );
  }
}
