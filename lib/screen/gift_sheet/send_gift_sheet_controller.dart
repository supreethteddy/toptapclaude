import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/manager/firebase_notification_manager.dart';
import 'package:shortzz/common/manager/haptic_manager.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/gift_wallet_service.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_dialog.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';

class SendGiftSheetController extends BaseController {
  Rx<Setting?> settings = Rx<Setting?>(null);
  Rx<User?> myUser = Rx<User?>(null);
  int? userId;
  List<AppUser> liveUsers;
  GiftType? giftType;
  String? roomID;
  late LivestreamScreenController livestreamController;
  bool _isSendingGift = false;

  SendGiftSheetController(this.giftType, this.userId, this.liveUsers,
      [this.roomID]);

  @override
  void onInit() {
    super.onInit();
    _initData();

    if (liveUsers.isNotEmpty &&
        (giftType == GiftType.livestream || giftType == GiftType.battle)) {
      livestreamController = Get.find<LivestreamScreenController>(tag: roomID);
      if (livestreamController.selectedGiftUser.value == null) {
        livestreamController.selectedGiftUser = liveUsers.first.obs;
      } else {
        DebounceAction.shared.call(() {
          livestreamController.selectedGiftUser.value = liveUsers.firstWhere(
              (element) =>
                  element.userId ==
                  livestreamController.selectedGiftUser.value?.userId,
              orElse: () => liveUsers.first);
        });
      }
    }
  }

  _initData() {
    settings.value = SessionManager.instance.getSettings();
    myUser.value = SessionManager.instance.getUser();
  }

  Future<void> onGiftTap(Gift gift) async {
    if (_isSendingGift) return;

    if (gift.id == null) {
      return showSnackBar('Gift Not Found');
    }

    final coinPrice = gift.coinPrice ?? 0;
    if (coinPrice <= 0) {
      return showSnackBar('This gift is not available right now.');
    }

    if (coinPrice > (myUser.value?.coinWallet ?? 0)) {
      return showSnackBar('Insufficient fund');
    }

    _isSendingGift = true;
    try {
      await sendGift(gift);
    } finally {
      _isSendingGift = false;
    }
  }

  Future<void> sendGift(Gift gift) async {
    final giftId = gift.id?.toInt() ?? -1;

    final coinPrice = gift.coinPrice ?? 0;
    final isLiveGift =
        giftType == GiftType.livestream || giftType == GiftType.battle;
    final recipientId = userId ??
        (isLiveGift
            ? livestreamController.selectedGiftUser.value?.userId
            : null);

    if (giftId == -1 || recipientId == null || recipientId < 0) {
      showSnackBar('The gift recipient is no longer available.');
      return Loggers.error('Invalid Gift: $giftId or User: $recipientId');
    }

    if (coinPrice <= 0) {
      return Loggers.error(
          'Invalid coin price: $coinPrice, skipping gift sending.');
    }
    var loaderVisible = false;
    try {
      showLoader();
      loaderVisible = true;
      final response = await GiftWalletService.instance
          .sendGift(giftId: giftId, userId: recipientId);
      stopLoader();
      loaderVisible = false;

      if (response.status == true) {
        // Deduct gift coins from user wallet
        myUser.update((val) {
          val?.removeCoinFromWallet(coinPrice);
        });
        Loggers.info(myUser.value?.coinWallet);
        SessionManager.instance.setUser(myUser.value);
        if (giftType == GiftType.none) {
          Get.back(result: GiftManager(gift));
        } else {
          Get.back(
              result: GiftManager(gift,
                  streamUser: livestreamController.selectedGiftUser.value));
        }
      } else {
        showSnackBar(response.message);
      }
    } catch (e, stack) {
      Loggers.error('Failed to send gift: $e\n$stack');
      showSnackBar('Unable to send the gift. Please try again.');
    } finally {
      if (loaderVisible) stopLoader();
    }
  }
}

class GiftManager {
  Gift gift;
  AppUser? streamUser;

  GiftManager(this.gift, {this.streamUser});

  static Future<void> openGiftSheet(
      {int? userId,
      Post? post,
      GiftType giftType = GiftType.none,
      BattleView battleViewType = BattleView.red,
      List<AppUser> streamUsers = const [],
      String? roomID,
      required Function(GiftManager giftManager) onCompletion}) async {
    await Get.bottomSheet<GiftManager>(
      SendGiftSheet(
        userId: userId,
        giftType: giftType,
        battleViewType: battleViewType,
        streamUsers: streamUsers,
        roomID: roomID,
      ),
      isScrollControlled: true,
    ).then((gift) {
      if (gift != null) {
        onCompletion(gift);
      }
    });
  }

  static void showAnimationDialog(Gift gift) {
    showGeneralDialog(
      context: Get.context!,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SendGiftDialog(gift: gift);
      },
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation);

        if (slideAnimation.isForwardOrCompleted) {
          HapticManager.shared.light();
        }

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  static void sendNotification(Post? post) {
    final user = post?.user;
    if (user == null || user.id == SessionManager.instance.getUserID()) return;

    if (user.notifyGiftReceived == 1) {
      FirebaseNotificationManager.instance.sendLocalisationNotification(
        LKey.activitySentGift.tr,
        type: NotificationType.post,
        deviceType: user.device,
        deviceToken: user.deviceToken,
        languageCode: user.appLanguage,
        body: NotificationInfo(id: post?.id),
      );
    }
  }
}
