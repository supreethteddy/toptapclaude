import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/controller/follow_controller.dart';
import 'package:toptap/common/service/api/user_service.dart';
import 'package:toptap/model/user_model/follower_model.dart';
import 'package:toptap/model/user_model/following_model.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/follow_following_screen/follow_following_screen.dart';

class FollowFollowingScreenController extends BaseController {
  RxInt selectedTabIndex = 0.obs;
  RxInt followerCount = 0.obs;
  RxInt followingCount = 0.obs;
  User? user;
  BuildContext context;

  FollowFollowingType followFollowingType;

  FollowFollowingScreenController(
      this.followFollowingType, this.user, this.context) {
    followerCount.value = user?.followerCount?.toInt() ?? 0;
    followingCount.value = user?.followingCount?.toInt() ?? 0;
  }

  RxList<Follower> followers = <Follower>[].obs;
  RxList<Following> followings = <Following>[].obs;

  RxBool isFollowers = false.obs;
  RxBool isFollowings = false.obs;

  ScrollController followerController = ScrollController();
  ScrollController followingController = ScrollController();
  PageController pageController = PageController();

  @override
  void onInit() {
    super.onInit();
    selectedTabIndex.value =
        followFollowingType == FollowFollowingType.follower ? 0 : 1;
    _initData();
  }

  @override
  void onReady() {
    super.onReady();
    pageController.animateToPage(selectedTabIndex.value,
        duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  Future<void> _initData() async {
    Future.wait({fetchFollowers(), fetchFollowings()});
  }

  Future<void> fetchFollowers() async {
    isFollowers.value = true;
    int lastId = followers.isEmpty ? -1 : followers.last.id ?? -1;

    List<Follower> list = await UserService.instance
        .fetchMyFollowers(lastItemId: lastId, userId: user?.id?.toInt());
    if (list.isNotEmpty) {
      followers.addAll(list);
    }
    isFollowers.value = false;
  }

  Future<void> fetchFollowings() async {
    isFollowings.value = true;
    int lastId = followings.isEmpty ? -1 : followings.last.id ?? -1;

    List<Following> list = await UserService.instance
        .fetchMyFollowing(lastItemId: lastId, userId: user?.id?.toInt());
    if (list.isNotEmpty) {
      followings.addAll(list);
    }
    isFollowings.value = false;
  }

  void onChangeTab(int value) {
    selectedTabIndex.value = value;
    if (value == 0) {
      followFollowingType = FollowFollowingType.follower;
    } else {
      followFollowingType = FollowFollowingType.following;
    }
    pageController.animateToPage(value,
        duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  void onFollowUnFollow(dynamic item) async {
    if (selectedTabIndex.value == 0) {
      _handleFollowerAction(item as Follower);
    } else {
      _handleFollowingAction(item as Following);
    }
  }

  void _handleFollowerAction(Follower data) async {
    int userId = data.fromUserId ?? -1;
    FollowController followController;
    if (Get.isRegistered<FollowController>(tag: userId.toString())) {
      followController = Get.find<FollowController>(tag: userId.toString());
    } else {
      followController =
          Get.put(FollowController(data.fromUser.obs), tag: userId.toString());
    }

    User? user = await followController.followUnFollowUser();
    if (user?.isFollowing ?? false) {
      for (var element in followers) {
        if (element.fromUserId == userId) {
          element.fromUser?.isFollowing = true;
        }
      }
    } else {
      for (var element in followers) {
        if (element.fromUserId == userId) {
          element.fromUser?.isFollowing = false;
        }
      }
    }
    followers.refresh();
  }

  void _handleFollowingAction(Following data) async {
    int userId = data.toUserId ?? -1;
    data.toUser?.isFollowing ??= true;

    FollowController followController;
    if (Get.isRegistered<FollowController>(tag: userId.toString())) {
      followController = Get.find<FollowController>(tag: userId.toString());
    } else {
      followController =
          Get.put(FollowController(data.toUser.obs), tag: userId.toString());
    }

    User? user = await followController.followUnFollowUser();
    if (user?.isFollowing ?? false) {
      for (var element in followings) {
        if (element.toUserId == userId) {
          element.toUser?.isFollowing = true;
        }
      }
    } else {
      for (var element in followings) {
        if (element.toUserId == userId) {
          element.toUser?.isFollowing = false;
        }
      }
    }
    followings.refresh();
  }

  @override
  void onClose() {
    super.onClose();
    followingController.dispose();
    followerController.dispose();
  }
}
