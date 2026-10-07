import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/service/api/gift_wallet_service.dart';
import 'package:shortzz/model/gift_wallet/coin_transaction_model.dart';

class CoinTransactionHistoryScreenController extends BaseController {
  RxList<CoinTransaction> transactions = <CoinTransaction>[].obs;
  // null = the "All" tab.
  Rx<String?> selectedType = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    _fetchTransactions();
  }

  void selectType(String? type) {
    if (selectedType.value == type) return;
    selectedType.value = type;
    transactions.clear();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    if (isLoading.value) return;
    isLoading.value = true;

    List<CoinTransaction> items =
        await GiftWalletService.instance.fetchCoinTransactions(
      type: selectedType.value,
      lastItemId: transactions.isEmpty ? null : transactions.last.id?.toInt(),
    );

    if (items.isNotEmpty) {
      transactions.addAll(items);
    }
    isLoading.value = false;
  }

  Future<void> loadMore() => _fetchTransactions();
}
