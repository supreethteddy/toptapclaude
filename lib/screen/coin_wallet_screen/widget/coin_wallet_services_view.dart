import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/help_center_screen/help_center_screen.dart';
import 'package:shortzz/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// "Services" section on the Balance screen.
///
/// NOTE: The Figma design also lists a "Transactions" entry here, but there
/// is no transaction-history model, service, or screen anywhere in this
/// codebase yet (the only wallet-related API call is
/// `GiftWalletService.instance.buyCoins`, which performs a purchase - it
/// does not expose any history/list endpoint). Building a "Transactions"
/// screen now would mean showing fake/empty data, so it is intentionally
/// left out until a real transaction-history API + screen exists.
class CoinWalletServicesView extends StatelessWidget {
  const CoinWalletServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: bgMediumGrey(context),
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          margin: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            LKey.services.tr,
            style: TextStyleCustom.outFitMedium500(
                    fontSize: 13, color: textLightGrey(context))
                .copyWith(letterSpacing: 2),
          ),
        ),
        SettingIconTextWithArrow(
          icon: AssetRes.ichelpicon,
          title: LKey.helpAndFeedback,
          onTap: () => Get.to(() => const HelpCenterScreen()),
        ),
      ],
    );
  }
}
