import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/gift_wallet_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';

class RequestWithdrawalScreenController extends BaseController {
  // true: cash out earningsBalanceUsd (real-money gift earnings) via
  // submitEarningsWithdrawalRequest. false (default): the original
  // coin_wallet -> coinValue flow via submitWithdrawalRequest. Same screen,
  // same gateway/account fields — only the balance, minimum, and submit
  // call differ.
  final bool isEarnings;

  RequestWithdrawalScreenController({this.isEarnings = false});

  Rx<Setting?> settings = Rx<Setting?>(null);
  Rx<User?> get myUser => SessionManager.instance.currentUser;

  RxString selectedGateway = ''.obs;
  TextEditingController amountController = TextEditingController();
  Rx<TextEditingController> estimatedAmountController =
      Rx(TextEditingController(text: '0'));
  TextEditingController accountDetailsController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _fetchLocalData();
  }

  void _fetchLocalData() {
    settings.value = SessionManager.instance.getSettings();
    myUser.value = SessionManager.instance.getUser();
    final gateways = settings.value?.redeemGateways ?? const [];
    if (selectedGateway.value.isEmpty && gateways.isNotEmpty) {
      selectedGateway.value = gateways.first.title ?? '';
    }
  }

  void onChanged(String value) {
    if (isEarnings) {
      // Amount entered here IS the USD value directly — no coin<->currency
      // conversion to show, unlike the coin flow below.
      return;
    }
    if (value.isEmpty) {
      estimatedAmountController.value.text = '0';
      return;
    }

    int maxAllowedCoins =
        myUser.value?.coinWallet?.toInt() ?? 0; // Dynamic max value
    int inputValue = int.tryParse(value) ?? 0;

    if (inputValue > maxAllowedCoins) {
      showSnackBar(LKey.youCanNotEnterMoreThanEtc
          .trParams({'coin': maxAllowedCoins.toString()}));
      amountController.text =
          maxAllowedCoins.toString(); // Set max value dynamically
      amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: amountController.text.length),
      );
    } else {
      estimatedAmountController.value.text =
          '${(settings.value?.coinValue?.toDouble() ?? 0) * inputValue}';
    }
  }

  Future<void> onSubmit() async {
    if (isEarnings) return _onSubmitEarnings();

    if ((settings.value?.redeemGateways ?? []).isEmpty) {
      return showSnackBar(LKey.redeemGatewayNotFound.tr);
    }
    final amount = int.tryParse(amountController.text.trim()) ?? 0;

    if (amount < (settings.value?.minRedeemCoins ?? 0)) {
      return showSnackBar(LKey.redeemMinCoinDescription.tr);
    }
    if (amount <= 0) {
      return showSnackBar('Enter a valid withdrawal amount');
    }
    if (amount > (myUser.value?.coinWallet?.toInt() ?? 0)) {
      return showSnackBar('You do not have enough coins');
    }
    if (selectedGateway.value.trim().isEmpty) {
      return showSnackBar('Select a withdrawal method');
    }
    if (accountDetailsController.text.trim().isEmpty) {
      return showSnackBar('Enter your account details');
    }

    showLoader();

    StatusModel model = await GiftWalletService.instance
        .submitWithdrawalRequest(
            coins: amountController.text.trim(),
            gateway: selectedGateway.value,
            account: accountDetailsController.text.trim());

    stopLoader();
    if (model.status == true) {
      myUser.value?.coinWallet = (myUser.value?.coinWallet ?? 0) - amount;
      SessionManager.instance.setUser(myUser.value);
      Get.back();
    }
    showSnackBar(model.message);
  }

  Future<void> _onSubmitEarnings() async {
    if ((settings.value?.redeemGateways ?? []).isEmpty) {
      return showSnackBar(LKey.redeemGatewayNotFound.tr);
    }
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final minAmount = settings.value?.minRedeemEarningsUsd ?? 5.0;
    final availableEarnings = myUser.value?.earningsBalanceUsd ?? 0;

    if (amount <= 0) {
      return showSnackBar('Enter a valid withdrawal amount');
    }
    if (amount < minAmount) {
      return showSnackBar(
          'Minimum withdrawal amount is ${minAmount.currencyFormat}');
    }
    if (amount > availableEarnings) {
      return showSnackBar('You do not have enough earnings');
    }
    if (selectedGateway.value.trim().isEmpty) {
      return showSnackBar('Select a withdrawal method');
    }
    if (accountDetailsController.text.trim().isEmpty) {
      return showSnackBar('Enter your account details');
    }

    showLoader();

    StatusModel model = await GiftWalletService.instance
        .submitEarningsWithdrawalRequest(
            amount: amountController.text.trim(),
            gateway: selectedGateway.value,
            account: accountDetailsController.text.trim());

    stopLoader();
    if (model.status == true) {
      myUser.value?.earningsBalanceUsd = availableEarnings - amount;
      SessionManager.instance.setUser(myUser.value);
      Get.back();
    }
    showSnackBar(model.message);
  }
}
