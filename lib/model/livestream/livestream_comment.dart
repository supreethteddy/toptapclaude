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

  LivestreamComment(
      {this.senderId,
      this.receiverId,
      this.comment,
      this.commentType,
      this.giftId,
      this.id,
      // this.senderUser,
      // this.receiverUser,
      this.gift});

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
