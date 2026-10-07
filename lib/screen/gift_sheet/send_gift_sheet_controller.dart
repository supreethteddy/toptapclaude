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
import 'package:shortzz/screen/coin_wallet_screen/coin_wallet_screen.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_dialog.dart';
import 'package:shortzz/screen/gift_sheet/send_gift_sheet.dart';
import 'package:shortzz/screen/live_stream/livestream_screen/livestream_screen_controller.dart';
import 'package:shortzz/utilities/app_res.dart';
import 'package:uuid/uuid.dart';

class SendGiftSheetController extends BaseController {
  Rx<Setting?> settings = Rx<Setting?>(null);
  // Shared with every other balance-displaying screen via SessionManager —
  // see CoinWalletScreenController for why.
  Rx<User?> get myUser => SessionManager.instance.currentUser;
  // '' means the "All" tab. Defaults to the catalog's first category once
  // settings load (see _initData).
  RxString selectedCategory = ''.obs;
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
  }

  /// Distinct categories in catalog order (admin-controlled via coin_price
  /// ordering upstream), so "Popular" naturally leads "Premium" etc. without
  /// a hardcoded category list here.
  List<String> get categories {
    final gifts = settings.value?.gifts ?? [];
    final seen = <String>{};
    final result = <String>[];
    for (final g in gifts) {
      final c = g.category;
      if (c != null && c.isNotEmpty && seen.add(c)) {
        result.add(c);
      }
    }
    return result;
  }

  List<Gift> get giftsForSelectedCategory {
    final gifts = settings.value?.gifts ?? [];
    if (selectedCategory.value.isEmpty) return gifts;
    return gifts.where((g) => g.category == selectedCategory.value).toList();
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  /// The LIVE room's host id, or null outside a livestream/battle gift.
  /// Passed to the server so it can apply the guest/host earnings split
  /// instead of giving the whole creator pool to the recipient alone when
  /// the recipient is a co-host/guest rather than the host.
  int? get _liveHostId {
    final isLiveGift =
        giftType == GiftType.livestream || giftType == GiftType.battle;
    if (!isLiveGift) return null;
    return livestreamController.liveData.value.hostId?.toInt();
  }

  // One id per distinct send attempt, reused across retries of that SAME
  // attempt (e.g. a thrown exception the user retries by tapping again) so
  // the server's idempotency check actually dedupes retries instead of
  // minting a new, uncorrelated key each time, defeating the point of it.
  // Reset (and cleared on success) whenever the attempted gift changes.
  String? _pendingIdempotencyKey;
  int? _pendingGiftId;

  String _idempotencyKeyFor(int giftId) {
    if (_pendingGiftId != giftId || _pendingIdempotencyKey == null) {
      _pendingGiftId = giftId;
      _pendingIdempotencyKey = const Uuid().v4();
    }
    return _pendingIdempotencyKey!;
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
      return _showInsufficientCoinsPrompt();
    }

    if (coinPrice >= AppRes.highValueGiftCoinThreshold) {
      final confirmed = await _confirmHighValueGift(gift);
      if (confirmed != true) return;
    }

    _isSendingGift = true;
    try {
      await sendGift(gift);
    } finally {
      _isSendingGift = false;
    }
  }

  Future<bool?> _confirmHighValueGift(Gift gift) {
    return Get.dialog<bool>(
      AlertDialog(
        title: Text(gift.name ?? 'Send this gift?'),
        content: Text(
            'Send ${gift.name ?? 'this gift'} for ${gift.coinPrice ?? 0} coins?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showInsufficientCoinsPrompt() {
    Get.dialog(
      AlertDialog(
        title: const Text('Not enough coins'),
        content: const Text(
            'You don\'t have enough coins to send this gift. Recharge your coin balance to continue.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.back();
              Get.to(() => const CoinWalletScreen());
            },
            child: const Text('Recharge Coins'),
          ),
        ],
      ),
    );
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
    // Direct gift to the room's own host (liveHostId == recipient) is
    // indistinguishable from a non-live gift server-side, so only pass it
    // when the recipient is someone else on the stream (a guest/co-host).
    final liveHostId =
        (_liveHostId != null && _liveHostId != recipientId) ? _liveHostId : null;
    var loaderVisible = false;
    try {
      showLoader();
      loaderVisible = true;
      final response = await GiftWalletService.instance.sendGift(
        giftId: giftId,
        userId: recipientId,
        idempotencyKey: _idempotencyKeyFor(giftId),
        liveHostId: liveHostId,
      );
      stopLoader();
      loaderVisible = false;

      if (response.status == true) {
        _pendingIdempotencyKey = null;
        _pendingGiftId = null;
        // Optimistic deduction for instant feedback, immediately corrected
        // by the server's own post-deduction figure — the balance is
        // server-authoritative, never trusted purely from client math.
        myUser.update((val) {
          val?.removeCoinFromWallet(coinPrice);
          if (response.coinWallet != null) {
            val?.coinWallet = response.coinWallet;
          }
        });
        SessionManager.instance.setUser(myUser.value);
        if (giftType == GiftType.none) {
          Get.back(result: GiftManager(gift));
        } else {
          Get.back(
              result: GiftManager(gift,
                  streamUser: livestreamController.selectedGiftUser.value));
        }
      } else {
        showSnackBar(response.message ?? 'Unable to send the gift.');
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
