import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/extensions/datetime_extention.dart';
import 'package:toptap/common/manager/firebase_notification_manager.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/service/api/api_service.dart';
import 'package:toptap/common/service/api/common_service.dart';
import 'package:toptap/common/service/api/post_service.dart';
import 'package:toptap/common/service/api/user_service.dart';
import 'package:toptap/common/service/location/location_service.dart';
import 'package:toptap/common/service/navigation/navigate_with_controller.dart';
import 'package:toptap/common/service/utils/params.dart';
import 'package:toptap/model/general/place_detail.dart';
import 'package:toptap/model/post_story/post_by_id.dart';
import 'package:toptap/model/post_story/post_model.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:toptap/screen/post_screen/single_post_screen.dart';
import 'package:toptap/screen/reels_screen/reels_screen.dart';
import 'package:toptap/screen/reels_screen/reels_screen_controller.dart';
import 'package:toptap/utilities/app_res.dart';

class HomeScreenController extends BaseController
    with GetSingleTickerProviderStateMixin, WidgetsBindingObserver {
  Rx<TabType> selectedReelCategory = TabType.values.first.obs;
  RxList<Post> reels = <Post>[].obs;
  late AnimationController controller;
  late Animation<double> animation;
  RxBool isAnimateTab = false.obs;
  StreamSubscription<Map>? streamSubscription;
  CancelToken token = CancelToken();

  Rx<User?> get myUser => Rx(SessionManager.instance.getUser());

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this); // Register observer

    controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    animation = CurvedAnimation(parent: controller, curve: Curves.linear);

    // Call both methods concurrently
    Future.wait([
      onRefreshPage(),
      _onNotificationTap(),
      _fetchLocation(),
      _readDeepLink(),
    ]);

    super.onInit();
  }

  @override
  void onReady() {
    isLoading.value = true;
    super.onReady();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this); // Unregister observer

    super.onClose();
    controller.dispose();
    streamSubscription?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        Loggers.warning("App Resumed");
        break;
      case AppLifecycleState.inactive:
        Loggers.warning("App Inactive");
        break;
      case AppLifecycleState.paused:
        Loggers.warning("App Paused");
        break;
      case AppLifecycleState.detached:
        Loggers.warning("App Detached");
        break;
      case AppLifecycleState.hidden:
        Loggers.warning("App Hidden");
        break;
    }
  }

  Future<void> _onNotificationTap() async {
    // Local notifications (including background call notifications) retain
    // their payload separately from FirebaseMessaging.getInitialMessage().
    final localPayload =
        FirebaseNotificationManager.instance.notificationPayload.value;
    if (localPayload.isNotEmpty) {
      await FirebaseNotificationManager.instance.handleNotification(
        localPayload,
      );
      FirebaseNotificationManager.instance.notificationPayload.value = '';
    }

    if (!Platform.isIOS) {
      // Set up a listener to handle future payload changes
      // Android: Get the message if the app was opened via notification
      RemoteMessage? message = await FirebaseMessaging.instance
          .getInitialMessage();

      if (message != null) {
        await FirebaseNotificationManager.instance.handleNotification(
          jsonEncode(message.toMap()),
        );
      }
    }

    FirebaseNotificationManager.instance.notificationPayload.listen((p0) {
      if (p0.isNotEmpty) {
        FirebaseNotificationManager.instance.handleNotification(p0);
        FirebaseNotificationManager.instance.notificationPayload.value = '';
      }
    });
  }

  Future<void> _readDeepLink() async {
    streamSubscription = FlutterBranchSdk.listSession().listen(
      (data) async {
        if (data.containsKey("+clicked_branch_link") &&
            data["+clicked_branch_link"] == true) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (data[Params.postId] != null) {
            int postId = int.parse(data[Params.postId]);
            PostByIdModel model = await PostService.instance.fetchPostById(
              postId: postId,
            );
            if (model.status == true) {
              Post? post = model.data?.post;
              if (post != null) {
                if (post.postType == PostType.reel) {
                  await Get.to(
                    () => ReelsScreen(reels: [post].obs, position: 0),
                    preventDuplicates: false,
                  );
                } else if ([
                  PostType.image,
                  PostType.video,
                  PostType.text,
                ].contains(post.postType)) {
                  await Get.to(
                    () =>
                        SinglePostScreen(post: post, isFromNotification: true),
                  );
                }
              }
            }
          } else if (data[Params.userId] != null) {
            int userId = int.parse(data[Params.userId]);
            User? user = await UserService.instance.fetchUserDetails(
              userId: userId,
            );
            if (user != null) {
              await NavigationService.shared.openProfileScreen(user);
            }
          }
        }
      },
      onError: (error) {
        Loggers.error('listSession error: ${error.toString()}');
      },
    );
  }

  Future<void> onRefreshPage({bool reset = true}) async {
    if (reset) {
      isLoading.value = true;
    }
    switch (selectedReelCategory.value) {
      case TabType.discover:
        await fetchDiscoverPost(reset);
        break;
      case TabType.following:
        await _fetchFollowingPost(reset);
        break;
      case TabType.nearby:
        try {
          await _fetchPostsNearBy(reset);
        } catch (e) {
          selectedReelCategory.value = TabType.discover;
        }
        break;
    }
  }

  onTabTypeChanged(TabType tabType) async {
    onAnimationBack();

    if (selectedReelCategory.value == tabType) return;

    // 👇 Special case: Open LiveStreamSearchScreen if user taps on `Live` tab
    if (tabType == TabType.nearby) {
      Get.to(() => const LiveStreamSearchScreen());
      return; // Skip updating tab or loading nearby reels
    }

    selectedReelCategory.value = tabType;
    await onRefreshPage(reset: true);
  }

  // Below is the Original Live Location Access Code
  // onTabTypeChanged(TabType tabType) async {
  //   onAnimationBack();
  //   if (selectedReelCategory.value == tabType) {
  //     return;
  //   }
  //   selectedReelCategory.value = tabType;
  //   await onRefreshPage.call(reset: true);
  // }

  onToggleDropDown() {
    if (animation.status != AnimationStatus.completed) {
      controller.forward();
      isAnimateTab.value = true;
    } else {
      onAnimationBack();
    }
  }

  onAnimationBack() {
    isAnimateTab.value = false;
    controller.animateBack(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.linear,
    );
  }

  Future<void> fetchDiscoverPost(bool resetData) async {
    isLoading.value = true;
    List<Post> newPosts = await PostService.instance.fetchPostsDiscover(
      type: PostType.reels,
      cancelToken: token,
    );
    print('FETCH NEW POST : ${newPosts.length}');
    addResponseData(newPosts, resetData);
  }

  Future<void> _fetchFollowingPost(bool resetData) async {
    isLoading.value = true;
    List<Post> newPosts = await PostService.instance.fetchPostsFollowing(
      type: PostType.reels,
      cancelToken: token,
    );

    addResponseData(newPosts, resetData);
  }

  Future<void> _fetchPostsNearBy(bool resetData) async {
    isLoading.value = true;
    Position position = await LocationService.instance.getCurrentLocation(
      isPermissionDialogShow: true,
    );
    List<Post> newPosts = await PostService.instance.fetchPostsNearBy(
      type: PostType.reels,
      placeLat: position.latitude,
      placeLon: position.longitude,
      cancelToken: token,
    );
    addResponseData(newPosts, resetData);
  }

  void addResponseData(List<Post> newPosts, bool resetData) {
    if (resetData) {
      reels.clear();
      if (Get.isRegistered<ReelsScreenController>(
        tag: ReelsScreenController.tag,
      )) {
        var controller = Get.find<ReelsScreenController>(
          tag: ReelsScreenController.tag,
        );
        controller.onRefreshPage(newPosts);
      }
    }
    if (newPosts.isNotEmpty) {
      reels.addAll(newPosts);
    }
    isLoading.value = false;
  }

  Future<void> _fetchLocation() async {
    PlaceDetail? detail;
    try {
      detail = await CommonService.instance.getIPPlaceDetail();
    } catch (e) {
      Loggers.error('Location error : $e');
    }

    if (detail != null) {
      DateTime time = DateTime.now().toUtc();
      UserService.instance.updateUserDetails(
        appLastUsed: time.formatTime,
        region: detail.region,
        regionName: detail.regionName,
        timezone: detail.timezone,
      );
    }
  }
}
