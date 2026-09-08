import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/utilities/app_res.dart';

/// True when the store (Google Play / App Store) billing is reachable.
bool isPurchaseConfig = false;

/// Verified-badge subscription state (drives the blue tick purchase screen).
RxBool isSubscribe = false.obs;

/// Store billing built on the official `in_app_purchase` plugin.
///
/// Replaces the RevenueCat SDK:
/// * coin packs = consumable products whose ids come from
///   admin > Coin packages (`playstore_product_id` / `appstore_product_id`);
/// * verified badge = subscription products listed in
///   [AppRes.verifiedBadgeProductIds].
///
/// The backend credits coins only after verifying the purchase token with
/// Google Play (see WalletController::buyCoins).
class SubscriptionManager {
  static var shared = SubscriptionManager();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// Subscription products (verified badge), most expensive first.
  List<ProductDetails> packages = [];

  /// Coin pack products.
  List<ProductDetails> offering = [];

  Completer<PurchaseDetails?>? _pendingPurchase;
  Completer<bool>? _pendingRestore;

  Set<String> get _coinProductIds {
    final plans = SessionManager.instance.getSettings()?.coinPackages ?? [];
    return plans
        .where((p) => p.status == 1)
        .map((p) => Platform.isIOS ? p.appstoreProductId : p.playStoreProductId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet();
  }

  Set<String> get _subscriptionIds => AppRes.verifiedBadgeProductIds.toSet();

  Future<void> initPlatformState() async {
    try {
      isPurchaseConfig = await _iap.isAvailable();
    } catch (e) {
      isPurchaseConfig = false;
      Loggers.warning('Store billing unavailable: $e');
    }
    if (!isPurchaseConfig) return;
    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) => Loggers.error('purchaseStream error: $e'),
    );
    await fetchOfferings();
  }

  /// Loads product details for coin packs and verified-badge subscriptions.
  Future<String?> fetchOfferings() async {
    if (!isPurchaseConfig) return 'Store billing is not available';
    final ids = {..._coinProductIds, ..._subscriptionIds};
    if (ids.isEmpty) return null;
    try {
      final response = await _iap.queryProductDetails(ids);
      if (response.notFoundIDs.isNotEmpty) {
        Loggers.warning('Store products not found: ${response.notFoundIDs}');
      }
      offering = response.productDetails
          .where((p) => _coinProductIds.contains(p.id))
          .toList()
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      packages = response.productDetails
          .where((p) => _subscriptionIds.contains(p.id))
          .toList()
        ..sort((a, b) => b.rawPrice.compareTo(a.rawPrice));
      return response.error?.message;
    } catch (e) {
      Loggers.error('queryProductDetails failed: $e');
      return '$e';
    }
  }

  /// Kept for call-site compatibility (RevenueCat needed a user login).
  Future<void> login(String appUserID) async {}

  /// Restores subscriptions silently at start-up to refresh [isSubscribe].
  Future<void> subscriptionListener() async {
    if (!isPurchaseConfig || _subscriptionIds.isEmpty) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      Loggers.warning('restorePurchases at start-up failed: $e');
    }
  }

  /// Buys a coin pack. Resolves with the purchase (token, product, date) or
  /// null when cancelled / failed.
  Future<PurchaseDetails?> makePurchaseCustom(ProductDetails product) async {
    if (!isPurchaseConfig) return null;
    _pendingPurchase?.complete(null);
    _pendingPurchase = Completer<PurchaseDetails?>();
    try {
      final param = PurchaseParam(productDetails: product);
      final started = await _iap.buyConsumable(purchaseParam: param);
      if (!started) {
        _pendingPurchase?.complete(null);
      }
    } catch (e) {
      Loggers.error('buyConsumable failed: $e');
      _pendingPurchase?.complete(null);
    }
    return _pendingPurchase!.future
        .timeout(const Duration(minutes: 5), onTimeout: () => null)
        .whenComplete(() => _pendingPurchase = null);
  }

  /// Buys a verified-badge subscription. Returns true when active.
  Future<bool?> makePurchase(ProductDetails product) async {
    if (!isPurchaseConfig) return null;
    _pendingPurchase?.complete(null);
    _pendingPurchase = Completer<PurchaseDetails?>();
    try {
      final param = PurchaseParam(productDetails: product);
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) _pendingPurchase?.complete(null);
    } catch (e) {
      Loggers.error('buyNonConsumable failed: $e');
      _pendingPurchase?.complete(null);
    }
    final details = await _pendingPurchase!.future
        .timeout(const Duration(minutes: 5), onTimeout: () => null)
        .whenComplete(() => _pendingPurchase = null);
    if (details == null) return null;
    isSubscribe.value = true;
    return true;
  }

  Future<bool?> restorePurchase() async {
    if (!isPurchaseConfig) return null;
    _pendingRestore = Completer<bool>();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      Loggers.error('restorePurchases failed: $e');
      return null;
    }
    final restored = await _pendingRestore!.future
        .timeout(const Duration(seconds: 20), onTimeout: () => false)
        .whenComplete(() => _pendingRestore = null);
    return restored;
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
        case PurchaseStatus.error:
          Loggers.warning(
              'Purchase ${purchase.productID} ${purchase.status}: ${purchase.error?.message}');
          _pendingPurchase?.complete(null);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_subscriptionIds.contains(purchase.productID)) {
            isSubscribe.value = true;
            if (purchase.status == PurchaseStatus.restored) {
              _pendingRestore?.complete(true);
            }
          }
          if (purchase.status == PurchaseStatus.purchased &&
              _pendingPurchase != null &&
              !_pendingPurchase!.isCompleted) {
            _pendingPurchase!.complete(purchase);
          }
          break;
      }
      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
    }
    if (_pendingRestore != null && !_pendingRestore!.isCompleted) {
      // Restore finished with no matching subscription.
      Future.delayed(const Duration(seconds: 2), () {
        if (_pendingRestore != null && !_pendingRestore!.isCompleted) {
          _pendingRestore!.complete(isSubscribe.value);
        }
      });
    }
  }

  /// Android purchase token / iOS receipt for server-side verification.
  static String verificationToken(PurchaseDetails details) {
    if (details is GooglePlayPurchaseDetails) {
      return details.billingClientPurchase.purchaseToken;
    }
    return details.verificationData.serverVerificationData;
  }

  static String storeName() => Platform.isIOS ? 'app_store' : 'play_store';
}
