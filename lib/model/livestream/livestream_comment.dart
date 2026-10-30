import 'package:get/get.dart';
import 'package:shortzz/common/controller/firebase_firestore_controller.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';

class LivestreamComment {
  int? senderId;
  int? receiverId;
  String? comment;
  LivestreamCommentType? commentType;
  int? giftId;
  int? id;

  // AppUser? senderUser;
  // AppUser? receiverUser;
  Gift? gift;

  // Gift accounting (LIVE spec Module 10.3) -- these are specific to this
  // one GIFT comment event, null for every other comment type. quantity is
  // always 1 today (no multi-gift-per-tap UI exists); kept explicit rather
  // than assumed so a future multi-send feature doesn't have to guess old
  // events meant 1. coinValue is a snapshot of the gift's real coin price
  // at send time (gift catalogue prices can change later). pkPoints is the
  // PK Match score this gift contributed -- null for a non-battle gift,
  // strictly 1:1 with the gift's real coin value (Final Tap-Tap & PK
  // Match Scoring Algorithm, client spec 2026-10-30), except it
  // deliberately ignores any first-gift-bonus multiplier baked into
  // coinValue (see _handleGiftSent's own comment on why those two can
  // differ). isGuestGift
  // mirrors the backend's own WalletController::sendGift flag: true when
  // this was sent via the guest-specific recipient path rather than
  // straight to the room's host. transactionId/transactionNumber link back
  // to the authoritative CoinTransactions row on the backend.
  int? quantity;
  int? coinValue;
  int? pkPoints;
  bool? isGuestGift;
  int? transactionId;
  String? transactionNumber;

  LivestreamComment(
      {this.senderId,
      this.receiverId,
      this.comment,
      this.commentType,
      this.giftId,
      this.id,
      // this.senderUser,
      // this.receiverUser,
      this.gift,
      this.quantity,
      this.coinValue,
      this.pkPoints,
      this.isGuestGift,
      this.transactionId,
      this.transactionNumber});

  LivestreamComment.fromJson(Map<String, dynamic> json) {
    senderId = json['sender_id'];
    receiverId = json['receiver_id'];
    comment = json['comment'];
    commentType = LivestreamCommentType.fromString(json['comment_type']);
    giftId = json['gift_id'];

    id = json['id'];
    // senderUser = json['sender_user'] != null
    //     ? AppUser.fromJson(json['sender_user'])
    //     : null;
    // receiverUser = json['receiver_user'] != null
    //     ? AppUser.fromJson(json['receiver_user'])
    //     : null;
    gift = json['gift'] != null ? Gift.fromJson(json['gift']) : null;
    quantity = json['quantity'];
    coinValue = json['coin_value'];
    pkPoints = json['pk_points'];
    isGuestGift = json['is_guest_gift'];
    transactionId = json['transaction_id'];
    transactionNumber = json['transaction_number'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['sender_id'] = senderId;
    data['receiver_id'] = receiverId;
    data['comment'] = comment;
    data['comment_type'] = commentType?.value;
    data['gift_id'] = giftId;
    data['id'] = id;
    // if (senderUser != null) {
    //   data['sender_user'] = senderUser?.toJson();
    // }
    // if (receiverUser != null) {
    //   data['receiver_user'] = receiverUser?.toJson();
    // }
    if (gift != null) {
      data['gift'] = gift?.toJson();
    }
    if (quantity != null) data['quantity'] = quantity;
    if (coinValue != null) data['coin_value'] = coinValue;
    if (pkPoints != null) data['pk_points'] = pkPoints;
    if (isGuestGift != null) data['is_guest_gift'] = isGuestGift;
    if (transactionId != null) data['transaction_id'] = transactionId;
    if (transactionNumber != null) {
      data['transaction_number'] = transactionNumber;
    }
    return data;
  }

  AppUser? get senderUser {
    final controller = Get.find<FirebaseFirestoreController>();
    return controller.users
        .firstWhereOrNull((element) => element.userId == senderId);
  }

  set senderUser(AppUser? user) {
    if (user == null) return;
    final controller = Get.find<FirebaseFirestoreController>();
    final index =
        controller.users.indexWhere((element) => element.userId == user.userId);
    if (index != -1) {
      controller.users[index] = user;
    } else {
      controller.users.add(user);
    }
  }

  AppUser? get receiverUser {
    final controller = Get.find<FirebaseFirestoreController>();
    return controller.users
        .firstWhereOrNull((element) => element.userId == receiverId);
  }

  set receiverUser(AppUser? user) {
    if (user == null) return;
    final controller = Get.find<FirebaseFirestoreController>();
    final index =
        controller.users.indexWhere((element) => element.userId == user.userId);
    if (index != -1) {
      controller.users[index] = user;
    } else {
      controller.users.add(user);
    }
  }
}

enum LivestreamCommentType {
  request('REQUEST'),
  text('TEXT'),
  gift('GIFT'),
  joined('JOINED'),
  joinedCoHost('JOINED_CO_HOST'),
  joinedGuest('JOINED_GUEST');

  final String value;

  const LivestreamCommentType(this.value);

  static LivestreamCommentType fromString(String value) {
    return LivestreamCommentType.values
            .firstWhereOrNull((e) => e.value == value) ??
        LivestreamCommentType.text;
  }
}
