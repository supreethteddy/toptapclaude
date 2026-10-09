import 'package:shortzz/common/service/api/api_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/common/service/utils/web_service.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/gift_wallet/coin_transaction_model.dart';
import 'package:shortzz/model/gift_wallet/withdraw_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/app_res.dart';

class GiftWalletService {
  GiftWalletService._();

  static final GiftWalletService instance = GiftWalletService._();

  /// [idempotencyKey]: a client-generated UUID, one per distinct send
  /// attempt (NOT regenerated on retry of the *same* attempt) — lets the
  /// server dedupe a retried/duplicated request so the gift is never charged
  /// twice. [liveHostId]: the LIVE room's host id, passed whenever the
  /// recipient is a co-host/guest rather than the host themself, so the
  /// server can apply the guest/host earnings split instead of giving the
  /// whole creator pool to the recipient alone.
  Future<SendGiftResult> sendGift({
    int? userId,
    int? giftId,
    String? idempotencyKey,
    int? liveHostId,
  }) async {
    SendGiftResult response = await ApiService.instance.call(
        url: WebService.giftWallet.sendGift,
        fromJson: SendGiftResult.fromJson,
        param: {
          Params.userId: userId,
          Params.giftId: giftId,
          if (idempotencyKey != null) Params.idempotencyKey: idempotencyKey,
          if (liveHostId != null) Params.liveHostId: liveHostId,
        });
    return response;
  }

  Future<List<CoinTransaction>> fetchCoinTransactions({
    String? type,
    int? lastItemId,
  }) async {
    CoinTransactionModel response = await ApiService.instance.call(
        url: WebService.giftWallet.fetchCoinTransactions,
        fromJson: CoinTransactionModel.fromJson,
        param: {
          Params.limit: AppRes.paginationLimit,
          if (type != null) Params.type: type,
          Params.lastItemId: lastItemId,
        });
    return response.data ?? [];
  }

  Future<List<Withdraw>> fetchMyWithdrawalRequest({int? lastItemId}) async {
    WithdrawModel response = await ApiService.instance.call(
        url: WebService.giftWallet.fetchMyWithdrawalRequest,
        fromJson: WithdrawModel.fromJson,
        param: {
          Params.limit: AppRes.paginationLimit,
          Params.lastItemId: lastItemId,
        });

    return response.data ?? [];
  }

  Future<StatusModel> submitWithdrawalRequest(
      {required String coins,
      required String gateway,
      required String account}) async {
    StatusModel response = await ApiService.instance.call(
        url: WebService.giftWallet.submitWithdrawalRequest,
        fromJson: StatusModel.fromJson,
        param: {
          Params.coins: coins,
          Params.gateway: gateway,
          Params.account: account
        });

    return response;
  }

  Future<StatusModel> submitEarningsWithdrawalRequest(
      {required String amount,
      required String gateway,
      required String account}) async {
    StatusModel response = await ApiService.instance.call(
        url: WebService.giftWallet.submitEarningsWithdrawalRequest,
        fromJson: StatusModel.fromJson,
        param: {
          Params.amount: amount,
          Params.gateway: gateway,
          Params.account: account
        });

    return response;
  }

  Future<User?> buyCoins(
      {required int id,
      String? purchasedAt,
      String? purchaseToken,
      String? productId,
      String? store}) async {
    UserModel response = await ApiService.instance.call(
        url: WebService.giftWallet.buyCoins,
        fromJson: UserModel.fromJson,
        param: {
          Params.coinPackageId: id,
          Params.purchasedAt: purchasedAt,
          if (purchaseToken != null) Params.purchaseToken: purchaseToken,
          if (productId != null) Params.productId: productId,
          if (store != null) Params.store: store,
        });
    if (response.status == true) {
      return response.data;
    }
    return null;
  }
}

/// sendGift's response: status/message plus the sender's fresh,
/// post-deduction coin_wallet straight from the server — used to correct the
/// client's optimistic local deduction instead of trusting client-side math
/// (the balance is server-authoritative; see WalletController::sendGift).
class SendGiftResult {
  SendGiftResult({this.status, this.message, this.coinWallet});

  SendGiftResult.fromJson(dynamic json) {
    status = json['status'];
    message = json['message'];
    coinWallet = json['data'] == null ? null : json['data']['coin_wallet'];
  }

  bool? status;
  String? message;
  num? coinWallet;
}
