import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/model/user_model/user_model.dart';

class SubscriptionScreenController extends BaseController {
  RxList<ProductDetails> packages = <ProductDetails>[].obs;
  Rx<ProductDetails?> selectedPackage = Rx(null);
  Function(User? user)? onUpdateUser;

  SubscriptionScreenController(this.onUpdateUser);

  @override
  void onInit() {
    super.onInit();
    packages.value = SubscriptionManager.shared.packages;
    if (packages.isNotEmpty) {
      selectedPackage.value = SubscriptionManager.shared.packages.first;
    }
  }

  void onMakePurchase() async {
    if (selectedPackage.value != null) {
      showLoader();
      bool? status = await SubscriptionManager.shared.makePurchase(selectedPackage.value!);
      stopLoader();
      if (status == true) {
        User? user = SessionManager.instance.getUser();
        user?.isVerify = 1;
        onUpdateUser?.call(user);
        SessionManager.instance.setUser(user);
        Get.back(result: true);
      }
    }
  }

  void onRestoreSubscription() async {
    showLoader();
    bool? status = await SubscriptionManager.shared.restorePurchase();
    stopLoader();
    if (status == true) {
      Get.back(result: true);
    }
  }

  void onSubscriptionTap(ProductDetails package) {
    selectedPackage.value = package;
    Loggers.success(selectedPackage.value?.id);
  }
}
