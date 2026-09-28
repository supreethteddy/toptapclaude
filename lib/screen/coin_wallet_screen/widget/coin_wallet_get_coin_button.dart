import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/text_button_custom.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:shortzz/screen/recharge_screen/recharge_screen.dart';

/// "Get coin" CTA on the Balance screen. Navigates to the Recharge screen
/// where the actual package grid + purchase flow lives.
class CoinWalletGetCoinButton extends StatelessWidget {
  final CoinWalletScreenController controller;

  const CoinWalletGetCoinButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextButtonCustom(
      title: LKey.getCoin.tr,
      btnHeight: 52,
      onTap: () {
        controller.clearSelection();
        Get.to(() => const RechargeScreen());
      },
    );
  }
}
