import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/functions/debounce_action.dart';
import 'package:shortzz/common/service/api/search_service.dart';
import 'package:shortzz/common/service/navigation/navigate_with_controller.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/app_res.dart';

class FindFriendsScreenController extends BaseController {
  RxList<User> users = <User>[].obs;
  RxBool isUsersLoading = false.obs;

  TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    searchUsers(reset: true);
  }

  void onSearchChanged(String value) {
    DebounceAction.shared.call(() {
      searchUsers(reset: true);
    }, milliseconds: 500);
  }

  Future<void> searchUsers({bool reset = false}) async {
    isUsersLoading.value = true;
    List<User> items = await SearchService.instance.searchUsers(
        lastItemId: reset ? null : users.lastOrNull?.id,
        keyword: searchController.text);
    if (reset) {
      users.clear();
    }
    if (items.isNotEmpty) {
      users.addAll(items);
    }
    isUsersLoading.value = false;
  }

  void onUserTap(User user) {
    NavigationService.shared.openProfileScreen(user);
  }

  void onInviteFriendsTap() {
    Share.share("Check out ${AppRes.appName} and let's connect!");
  }
}
