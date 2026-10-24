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
  /// whole creator pool to the recipient alone. [isLiveGift]: whether this
  /// gift was sent from the LIVE screen at all (host or guest recipient) --
  /// unlike [liveHostId], always sent, so the server can tell a LIVE gift
  /// apart from a story/chat/post/reel gift (otherwise identical requests)
  /// and gate the daily/hourly/League LIVE-ranking writes accordingly.
  Future<SendGiftResult> sendGift({
    int? userId,
    int? giftId,
    String? idempotencyKey,
    int? liveHostId,
    bool isLiveGift = false,
  }) async {
    SendGiftResult response = await ApiService.instance.call(
        url: WebService.giftWallet.sendGift,
        fromJson: SendGiftResult.fromJson,
        param: {
          Params.userId: userId,
          Params.giftId: giftId,
          if (idempotencyKey != null) Params.idempotencyKey: idempotencyKey,
          if (liveHostId != null) Params.liveHostId: liveHostId,
          Params.isLiveGift: isLiveGift,
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
  SendGiftResult(
      {this.status,
      this.message,
      this.coinWallet,
      this.transactionId,
      this.transactionNumber});

  SendGiftResult.fromJson(dynamic json) {
    status = json['status'];
    message = json['message'];
    coinWallet = json['data'] == null ? null : json['data']['coin_wallet'];
    transactionId = json['data'] == null ? null : json['data']['transaction_id'];
    transactionNumber =
        json['data'] == null ? null : json['data']['transaction_number'];
  }

  bool? status;
  String? message;
  num? coinWallet;
  // The backend's own CoinTransactions row for this send (see
  // WalletController::sendGift / GlobalFunction::recordCoinTransaction) --
  // the authoritative financial record. Threaded through GiftManager into
  // the Firestore gift comment event so that event can reference it
  // instead of being the only record of this gift (LIVE spec Module 10.3).
  int? transactionId;
  String? transactionNumber;
}
