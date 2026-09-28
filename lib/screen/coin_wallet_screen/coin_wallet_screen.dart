import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:shortzz/screen/coin_wallet_screen/widget/coin_wallet_first_purchase_banner.dart';
import 'package:shortzz/screen/coin_wallet_screen/widget/coin_wallet_get_coin_button.dart';
import 'package:shortzz/screen/coin_wallet_screen/widget/coin_wallet_services_view.dart';
import 'package:shortzz/screen/coin_wallet_screen/widget/coin_wallet_top_view.dart';

/// "Balance" screen (per Figma): shows the coin balance, lifetime
/// stats + withdrawal menu (all still in [CoinWalletTopView]), a "Get Coin"
/// action that opens the new package-purchase flow, a first-purchase promo
/// banner and a "Services" section. The actual package grid + purchase flow
/// now lives in `lib/screen/recharge_screen/recharge_screen.dart`.
class CoinWalletScreen extends StatelessWidget {
  const CoinWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CoinWalletScreenController());
    return Scaffold(
      body: Column(
        children: [
          const CoinWalletTopView(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CoinWalletGetCoinButton(controller: controller),
                  const SizedBox(height: 16),
                  CoinWalletFirstPurchaseBanner(controller: controller),
                  const SizedBox(height: 8),
                  const CoinWalletServicesView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
