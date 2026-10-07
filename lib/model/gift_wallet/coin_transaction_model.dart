import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';

class CoinTransactionModel {
  CoinTransactionModel({
    this.status,
    this.message,
    this.data,
  });

  CoinTransactionModel.fromJson(dynamic json) {
    status = json['status'];
    message = json['message'];
    if (json['data'] != null) {
      data = [];
      json['data'].forEach((v) {
        data?.add(CoinTransaction.fromJson(v));
      });
    }
  }

  bool? status;
  String? message;
  List<CoinTransaction>? data;
}

/// tbl_coin_transactions row: recharge, gift_sent, gift_received, or
/// withdrawal. [coinAmount] is the signed delta applied to coin_wallet
/// (negative for gift_sent, 0 for gift_received since that credits
/// [usdAmount] onto earnings instead). See WalletController::sendGift /
/// buyCoins on the backend.
class CoinTransaction {
  CoinTransaction({
    this.id,
    this.transactionNumber,
    this.userId,
    this.type,
    this.coinAmount,
    this.usdAmount,
    this.relatedUserId,
    this.giftId,
    this.status,
    this.createdAt,
    this.relatedUser,
    this.gift,
  });

  CoinTransaction.fromJson(dynamic json) {
    id = json['id'];
    transactionNumber = json['transaction_number'];
    userId = json['user_id'];
    type = json['type'];
    coinAmount = json['coin_amount'];
    usdAmount = json['usd_amount'] == null
        ? null
        : num.tryParse(json['usd_amount'].toString());
    relatedUserId = json['related_user_id'];
    giftId = json['gift_id'];
    status = json['status'];
    createdAt = json['created_at'];
    relatedUser =
        json['related_user'] == null ? null : User.fromJson(json['related_user']);
    gift = json['gift'] == null ? null : Gift.fromJson(json['gift']);
  }

  num? id;
  String? transactionNumber;
  num? userId;
  String? type;
  num? coinAmount;
  num? usdAmount;
  num? relatedUserId;
  num? giftId;
  String? status;
  String? createdAt;
  User? relatedUser;
  Gift? gift;

  bool get isCredit => type == 'recharge' || type == 'gift_received';
}

abstract class CoinTransactionType {
  static const String recharge = 'recharge';
  static const String giftSent = 'gift_sent';
  static const String giftReceived = 'gift_received';
  static const String withdrawal = 'withdrawal';
}
