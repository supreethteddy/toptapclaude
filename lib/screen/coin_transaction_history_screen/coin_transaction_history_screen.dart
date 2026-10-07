import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_app_bar.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/gift_wallet/coin_transaction_model.dart';
import 'package:shortzz/screen/coin_transaction_history_screen/coin_transaction_history_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/style_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class CoinTransactionHistoryScreen extends StatelessWidget {
  const CoinTransactionHistoryScreen({super.key});

  static const _tabs = <String?, String>{
    null: 'All',
    CoinTransactionType.recharge: 'Recharge',
    CoinTransactionType.giftSent: 'Sent',
    CoinTransactionType.giftReceived: 'Received',
  };

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CoinTransactionHistoryScreenController());
    return Scaffold(
      body: Column(
        children: [
          const CustomAppBar(title: 'Transaction History'),
          SizedBox(
            height: 40,
            child: Obx(() => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  children: _tabs.entries.map((entry) {
                    final isSelected = controller.selectedType.value == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => controller.selectType(entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: isSelected ? StyleRes.themeGradient : null,
                            color: isSelected ? null : bgLightGrey(context),
                          ),
                          alignment: Alignment.center,
                          child: Text(entry.value,
                              style: TextStyleCustom.outFitMedium500(
                                  fontSize: 13,
                                  color: isSelected
                                      ? whitePure(context)
                                      : textLightGrey(context))),
                        ),
                      ),
                    );
                  }).toList(),
                )),
          ),
          Expanded(child: Obx(
            () {
              return controller.isLoading.value && controller.transactions.isEmpty
                  ? const LoaderWidget()
                  : NoDataView(
                      showShow: !controller.isLoading.value &&
                          controller.transactions.isEmpty,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 200) {
                            controller.loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          itemCount: controller.transactions.length,
                          padding: const EdgeInsets.only(top: 1),
                          itemBuilder: (context, index) {
                            return _TransactionTile(
                                transaction: controller.transactions[index]);
                          },
                        ),
                      ),
                    );
            },
          ))
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final CoinTransaction transaction;

  const _TransactionTile({required this.transaction});

  String get _title {
    switch (transaction.type) {
      case CoinTransactionType.recharge:
        return 'Coin Recharge';
      case CoinTransactionType.giftSent:
        final name = transaction.relatedUser?.fullname;
        final gift = transaction.gift?.name;
        return 'Sent ${gift ?? 'a gift'}${name != null ? ' to $name' : ''}';
      case CoinTransactionType.giftReceived:
        final name = transaction.relatedUser?.fullname;
        final gift = transaction.gift?.name;
        return 'Earned from ${gift ?? 'a gift'}${name != null ? ' via $name' : ''}';
      case CoinTransactionType.withdrawal:
        return 'Withdrawal';
      default:
        return transaction.type ?? 'Transaction';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? ColorRes.green : ColorRes.likeRed;
    final coinAmount = transaction.coinAmount ?? 0;
    final usdAmount = transaction.usdAmount;

    return Container(
      color: bgLightGrey(context),
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyleCustom.outFitMedium500(
                        fontSize: 14, color: textDarkGrey(context))),
                const SizedBox(height: 3),
                Text('${AppRes.hash}${transaction.transactionNumber ?? ''}',
                    style: TextStyleCustom.outFitLight300(
                        fontSize: 12, color: textLightGrey(context))),
                Text((transaction.createdAt ?? '').formatDate1,
                    style: TextStyleCustom.outFitLight300(
                        fontSize: 12, color: textLightGrey(context))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (coinAmount != 0)
                Text(
                    '${coinAmount > 0 ? '+' : ''}${coinAmount.toInt().numberFormat} ${LKey.coins.tr}',
                    style: TextStyleCustom.outFitBold700(
                        fontSize: 15, color: color)),
              if (usdAmount != null && usdAmount > 0)
                Text('+${usdAmount.currencyFormat}',
                    style: TextStyleCustom.outFitBold700(
                        fontSize: 15, color: ColorRes.green)),
            ],
          ),
        ],
      ),
    );
  }
}
