// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:shortzz/common/controller/base_controller.dart';
// import 'package:shortzz/common/manager/logger.dart';
// import 'package:shortzz/common/manager/session_manager.dart';
// import 'package:shortzz/common/service/subscription/subscription_manager.dart';
// import 'package:shortzz/common/widget/restart_widget.dart';
// import 'package:shortzz/languages/languages_keys.dart';
// import 'package:shortzz/model/chat/chat_thread.dart';
// import 'package:shortzz/model/general/settings_model.dart';
// import 'package:shortzz/model/user_model/user_model.dart';
// import 'package:shortzz/screen/camera_screen/camera_screen.dart';
// import 'package:shortzz/screen/feed_screen/feed_screen_controller.dart';
// import 'package:shortzz/utilities/asset_res.dart';
// import 'package:shortzz/utilities/firebase_const.dart';
// import 'package:zego_express_engine/zego_express_engine.dart';

// class DashboardScreenController extends BaseController
//     with GetSingleTickerProviderStateMixin {
//   List<String> bottomIconList = [
//     AssetRes.icReel,
//     // AssetRes.icPost,
//     // AssetRes.icLiveStream,
//     AssetRes.icSearch,
//     AssetRes.icPlus,
//     AssetRes.icChat,
//     AssetRes.icProfile
//   ];
//   RxInt selectedPageIndex = 0.obs;
//   RxDouble scaleValue = 1.0.obs;
//   Function(int index)? onBottomIndexChanged;
//   Rx<PostUploadingProgress> postProgress =
//       Rx(PostUploadingProgress());
//   Function(PostUploadingProgress progress) onProgress =
//       (_) {};

//   late AnimationController animationController;

//   FirebaseFirestore db = FirebaseFirestore.instance;
//   RxInt unReadCount = 0.obs;

//   late StreamSubscription _unReadCountSubscription;
//   late Animation<double> scaleAnimation;
//   User? user = SessionManager.instance.getUser();

//   @override
//   void onInit() {
//     super.onInit();

//     animationController = AnimationController(
//         duration: const Duration(milliseconds: 200),
//         vsync: this);
//     scaleAnimation =
//         Tween<double>(begin: 0.5, end: 1.0).animate(
//       CurvedAnimation(
//           parent: animationController,
//           curve: Curves.easeInOut),
//     )..addListener(() {
//             scaleValue.value = scaleAnimation
//                 .value; // Update reactive scale value
//           });
//     onProgress = (progress) {
//       postProgress.value = progress;
//     };
//   }

//   @override
//   void onReady() async {
//     super.onReady();
//     SubscriptionManager.shared.subscriptionListener();

//     createZegoEngine();

//     // Run below in parallel
//     _fetchLanguageFromUser();
//     _fetchUnReadCount();
//   }

//   @override
//   void onClose() {
//     animationController.dispose();
//     _unReadCountSubscription.cancel();
//     super.onClose();
//   }

//   onChanged(int index) {
//     // if (index == 1) {
//     //   onFeedPostScrollDown(index);
//     // }
//     if (selectedPageIndex.value == index) return;
//     HapticFeedback.lightImpact();
//     onBottomIndexChanged?.call(index);
//     selectedPageIndex.value = index;
//     animationController
//       ..reset()
//       ..forward();
//   }

//   onFeedPostScrollDown(int index) {
//     if (selectedPageIndex.value != index) return;
//     if (Get.isRegistered<FeedScreenController>()) {
//       final controller = Get.find<FeedScreenController>();
//       if (controller.posts.isNotEmpty &&
//           !controller.isLoading.value) {
//         controller.postScrollController.animateTo(0.0,
//             duration: const Duration(milliseconds: 150),
//             curve: Curves.linear);
//         controller.refreshKey.currentState?.show();
//       }
//     }
//   }

//   void _fetchUnReadCount() {
//     _unReadCountSubscription = db
//         .collection(FirebaseConst.users)
//         .doc(user?.id.toString())
//         .collection(FirebaseConst.usersList)
//         .where(FirebaseConst.isDeleted, isEqualTo: false)
//         .withConverter(
//             fromFirestore: (snapshot, options) =>
//                 ChatThread.fromJson(snapshot.data()!),
//             toFirestore: (ChatThread value, options) =>
//                 value.toJson())
//         .snapshots()
//         .listen((event) {
//       final count = event.docs
//           .where((doc) => (doc.data().msgCount ?? 0) > 0)
//           .length;
//       unReadCount.value = count;
//     });
//   }

//   Future<void> createZegoEngine() async {
//     Setting? appSetting =
//         SessionManager.instance.getSettings();
//     int appId = int.parse(appSetting?.zegoAppId ?? '0');
//     try {
//       await ZegoExpressEngine.createEngineWithProfile(
//           ZegoEngineProfile(appId, ZegoScenario.Default,
//               appSign: appSetting?.zegoAppSign));
//     } on MissingPluginException catch (e) {
//       Loggers.error('Create Zego Engine : ${e.message}');
//     }
//   }

//   Future<void> _fetchLanguageFromUser() async {
//     String savedLanguage =
//         SessionManager.instance.getLang();
//     String userLanguage = user?.appLanguage ?? 'en';
//     if (userLanguage != savedLanguage) {
//       SessionManager.instance.setLang(userLanguage);
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         RestartWidget.restartApp(Get.context!);
//       });
//     }
//   }
// }

// class PostUploadingProgress {
//   final CameraScreenType type;
//   final UploadType uploadType;
//   final double progress;

//   PostUploadingProgress(
//       {this.type = CameraScreenType.post,
//       this.progress = 0,
//       this.uploadType = UploadType.none});
// }

// enum UploadType {
//   none,
//   finish,
//   error,
//   uploading;

//   String title(CameraScreenType type) {
//     switch (this) {
//       case UploadType.none:
//         return '';
//       case UploadType.finish:
//         return type == CameraScreenType.post
//             ? LKey.postUploadSuccessfully.tr
//             : LKey.storyUploadSuccess.tr;
//       case UploadType.error:
//         return LKey.uploadingFailed.tr;
//       case UploadType.uploading:
//         return type == CameraScreenType.post
//             ? LKey.postIsBeginUploading.tr
//             : LKey.storyIsBeginUploading.tr;
//     }
//   }
// }

//---------------------------->

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/subscription/subscription_manager.dart';
import 'package:shortzz/common/service/zego_engine_service.dart';
import 'package:shortzz/common/widget/restart_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/camera_screen/camera_screen.dart';
import 'package:shortzz/screen/camera_screen/camera_types.dart';
import 'package:shortzz/screen/message_screen/message_screen_controller.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/firebase_const.dart';
import 'package:shortzz/screen/feed_screen/feed_screen_controller.dart';

class DashboardScreenController extends BaseController
    with GetSingleTickerProviderStateMixin {
  List<String> bottomIconList = [
    AssetRes.icReel,
    AssetRes.icAudience,
    AssetRes.icPlusDark, // Placeholder for center '+' button
    AssetRes.icChat,
    AssetRes.icProfile
  ];

  RxInt selectedPageIndex = 0.obs;
  RxDouble scaleValue = 1.0.obs;
  Function(int index)? onBottomIndexChanged;
  Rx<PostUploadingProgress> postProgress = Rx(PostUploadingProgress());
  Function(PostUploadingProgress progress) onProgress = (_) {};

  late AnimationController animationController;

  FirebaseFirestore db = FirebaseFirestore.instance;
  RxInt unReadCount = 0.obs;

  late StreamSubscription _unReadCountSubscription;
  late Animation<double> scaleAnimation;
  User? user = SessionManager.instance.getUser();

  @override
  void onInit() {
    super.onInit();

    animationController = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    )..addListener(() {
        scaleValue.value = scaleAnimation.value;
      });
    onProgress = (progress) {
      postProgress.value = progress;
    };
  }

  @override
  void onReady() async {
    super.onReady();
    SubscriptionManager.shared.subscriptionListener();
    createZegoEngine();
    _fetchLanguageFromUser();
    _fetchUnReadCount();
  }

  @override
  void onClose() {
    animationController.dispose();
    _unReadCountSubscription.cancel();
    super.onClose();
  }

  void onChanged(int index) {
    if (index == 2) {
      // DeepAR Camera with AR filters
      print(
          '🎯 Camera button tapped from tab index: ${selectedPageIndex.value}');

      // TODO: Pass intended content type to DeepAR camera once integrated
      // PostStoryContentType? intendedContentType;
      // switch (selectedPageIndex.value) {
      //   case 0: intendedContentType = null; // Feed - choice dialog
      //   case 1: intendedContentType = PostStoryContentType.storyVideo; // Messages
      //   case 3: intendedContentType = PostStoryContentType.storyVideo; // Discover
      //   case 4: intendedContentType = PostStoryContentType.reel; // Profile
      //   default: intendedContentType = null;
      // }

      // Launch camera - show options sheet for post/story/reel
      // For now, default to post (reels)
      Get.to(() => const CameraScreen(cameraType: CameraScreenType.post));
      return;
    }

    // Refresh message screen when navigating to it
    if (index == 1) {
      Loggers.success('🔄 Navigating to Messages - triggering refresh');
      try {
        final messageController = Get.find<MessageScreenController>();
        messageController.refreshMessages();
      } catch (e) {
        Loggers.warning(
            'Message controller not found, will be initialized when screen loads');
      }
    }

    // Below is the original code
    // if (index == 2) {
    //   // Center '+' tapped
    //   final user = SessionManager.instance.getUser();
    //   if (user != null) {
    //     final controller = Get.put(
    //       ProfileScreenController(user.obs, (user) {}),
    //       tag: '${user.id}',
    //     );
    //     showModalBottomSheet(
    //       context: Get.context!,
    //       isScrollControlled: true,
    //       backgroundColor: Colors.transparent,
    //       builder: (_) =>
    //           PostOptionsSheet(controller: controller),
    //     );
    //   }
    //   return;
    // }

    if (selectedPageIndex.value == index) return;
    HapticFeedback.lightImpact();
    onBottomIndexChanged?.call(index);
    selectedPageIndex.value = index;
    animationController
      ..reset()
      ..forward();
  }

  void onFeedPostScrollDown(int index) {
    if (selectedPageIndex.value != index) return;
    if (Get.isRegistered<FeedScreenController>()) {
      final controller = Get.find<FeedScreenController>();
      if (controller.posts.isNotEmpty && !controller.isLoading.value) {
        controller.postScrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 150), curve: Curves.linear);
        controller.refreshKey.currentState?.show();
      }
    }
  }

  void _fetchUnReadCount() {
    _unReadCountSubscription = db
        .collection(FirebaseConst.users)
        .doc(user?.id.toString())
        .collection(FirebaseConst.usersList)
        .where(FirebaseConst.isDeleted, isEqualTo: false)
        .withConverter(
            fromFirestore: (snapshot, options) =>
                ChatThread.fromJson(snapshot.data()!),
            toFirestore: (ChatThread value, options) => value.toJson())
        .snapshots()
        .listen((event) {
      int chatCount = 0;
      int requestCount = 0;

      for (var doc in event.docs) {
        final chatThread = doc.data();
        final msgCount = chatThread.msgCount ?? 0;

        if (msgCount > 0) {
          if (chatThread.chatType == ChatType.approved) {
            chatCount++;
          } else {
            requestCount++;
          }
        }
      }

      final totalCount = chatCount + requestCount;
      unReadCount.value = totalCount;

      Loggers.success(
          '📱 Unread count updated: $totalCount (chats: $chatCount, requests: $requestCount)');
    }, onError: (error) {
      Loggers.error('❌ Unread count stream error: $error');
    });
  }

  Future<void> createZegoEngine() async {
    bool isReady = await ZegoEngineService.instance.ensureEngine();
    if (!isReady) {
      Loggers.error('Create Zego Engine failed');
    }
  }

  Future<void> _fetchLanguageFromUser() async {
    String savedLanguage = SessionManager.instance.getLang();
    String userLanguage = user?.appLanguage ?? 'en';
    if (userLanguage != savedLanguage) {
      SessionManager.instance.setLang(userLanguage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        RestartWidget.restartApp(Get.context!);
      });
    }
  }
}

class PostUploadingProgress {
  final CameraScreenType type;
  final UploadType uploadType;
  final double progress;

  PostUploadingProgress(
      {this.type = CameraScreenType.post,
      this.progress = 0,
      this.uploadType = UploadType.none});
}

enum UploadType {
  none,
  finish,
  error,
  uploading;

  String title(CameraScreenType type) {
    switch (this) {
      case UploadType.none:
        return '';
      case UploadType.finish:
        return type == CameraScreenType.post
            ? LKey.postUploadSuccessfully.tr
            : LKey.storyUploadSuccess.tr;
      case UploadType.error:
        return LKey.uploadingFailed.tr;
      case UploadType.uploading:
        return type == CameraScreenType.post
            ? LKey.postIsBeginUploading.tr
            : LKey.storyIsBeginUploading.tr;
    }
  }
}
