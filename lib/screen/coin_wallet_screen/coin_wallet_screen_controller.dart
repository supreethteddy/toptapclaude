
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/gift_wallet_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';

class CoinWalletScreenController extends BaseController {
  Rx<User?> myUser = Rx<User?>(null);
  RxList<ProductDetails> offerings = <ProductDetails>[].obs;

  Setting? get settings => SessionManager.instance.getSettings();
  RxList<CoinPlan> coinPlans = <CoinPlan>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
    fetchOfferings();
  }

  void fetchData() {
    myUser.value = SessionManager.instance.getUser();
  }

  Future<void> fetchOfferings() async {
    if (SubscriptionManager.shared.offering.isEmpty && isPurchaseConfig) {
      await SubscriptionManager.shared.fetchOfferings();
    }
    List<ProductDetails> items = SubscriptionManager.shared.offering;
    offerings.assignAll(items);
    coinPlans.clear();
    if (settings?.coinPackages == null) return;

    for (var data in settings!.coinPackages!) {
      if (data.status == 1) {
        for (var element in items) {
          if ([data.appstoreProductId, data.playStoreProductId]
              .contains(element.id)) {
            coinPlans.add(CoinPlan(
                data.coinAmount ?? 0, data.id ?? -1, element.id, element.price));
          }
        }
      }
    }
  }

  void onPurchase(CoinPlan offer) {
    final product =
        offerings.firstWhereOrNull((element) => element.id == offer.id);
    if (product == null) {
      showSnackBar('This coin pack is not available in the store yet.');
      return;
    }
    showLoader(barrierDismissible: false);
    SubscriptionManager.shared.makePurchaseCustom(product).then((value) async {
      if (value != null) {
        final millis = int.tryParse(value.transactionDate ?? '') ??
            DateTime.now().millisecondsSinceEpoch;
        User? user = await GiftWalletService.instance.buyCoins(
          id: offer.coinPackageId,
          purchasedAt: millis.toString(),
          purchaseToken: SubscriptionManager.verificationToken(value),
          productId: value.productID,
          store: SubscriptionManager.storeName(),
        );
        stopLoader();
        if (user != null) {
          User? user = await UserService.instance
              .fetchUserDetails(userId: myUser.value?.id);
          if (user != null) {
            myUser.value = user;
            SessionManager.instance.setUser(myUser.value);
          }
        }
      } else {
        stopLoader();
      }
    });
  }

}

class CoinPlan {
  int coin;
  int coinPackageId;
  String id;
  String priceString;

  CoinPlan(this.coin, this.coinPackageId, this.id, this.priceString);
}
