import 'dart:async';

import 'package:get/get.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/utilities/app_res.dart';

/// Backs the Friends / Recommended lists in the Invited tab: people the host
/// can invite who are NOT in the room (the in-room list stays on the
/// LivestreamScreenController). Friends = my followings; Recommended = my
/// followers I don't follow back, or a username search when the box has
/// text. Pure data — the button states come from the room controller.
class InviteCandidatesController extends GetxController {
  final RxList<User> friends = <User>[].obs;
  final RxList<User> recommended = <User>[].obs;
  final RxList<User> searchResults = <User>[].obs;
  final RxBool isLoadingFriends = false.obs;
  final RxBool isLoadingRecommended = false.obs;
  final RxBool isSearching = false.obs;
  final RxString query = ''.obs;

  Timer? _debounce;
  bool _loadedFriends = false;
  bool _loadedRecommended = false;

  int get _myId => SessionManager.instance.getUserID();

  @override
  void onInit() {
    super.onInit();
    unawaited(loadFriends());
    unawaited(loadRecommended());
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> loadFriends() async {
    if (_loadedFriends || isLoadingFriends.value) return;
    isLoadingFriends.value = true;
    try {
      final following = await UserService.instance
          .fetchMyFollowing(lastItemId: -1, userId: _myId);
      friends.value = following
          .map((f) => f.toUser)
          .whereType<User>()
          .where((u) => u.id != null && u.id != _myId)
          .toList();
      _loadedFriends = true;
    } catch (e) {
      Loggers.error('Invite candidates: loading followings failed: $e');
    } finally {
      isLoadingFriends.value = false;
    }
  }

  Future<void> loadRecommended() async {
    if (_loadedRecommended || isLoadingRecommended.value) return;
    isLoadingRecommended.value = true;
    try {
      final followers = await UserService.instance
          .fetchMyFollowers(lastItemId: -1, userId: _myId);
      recommended.value = followers
          .map((f) => f.fromUser)
          .whereType<User>()
          .where((u) =>
              u.id != null && u.id != _myId && u.isFollowing != true)
          .toList();
      _loadedRecommended = true;
    } catch (e) {
      Loggers.error('Invite candidates: loading followers failed: $e');
    } finally {
      isLoadingRecommended.value = false;
    }
  }

  /// Debounced username search for the Recommended list; clearing the box
  /// goes back to the follower-based suggestions.
  void onSearchChanged(String value) {
    query.value = value.trim();
    _debounce?.cancel();
    if (query.value.isEmpty) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final keyword = query.value;
      if (keyword.isEmpty) return;
      isSearching.value = true;
      try {
        final users = await UserService.instance.searchUsers(
          keyWord: keyword,
          limit: AppRes.paginationLimit,
        );
        // A newer keystroke may have superseded this request.
        if (query.value != keyword) return;
        searchResults.value =
            users.where((u) => u.id != null && u.id != _myId).toList();
      } catch (e) {
        Loggers.error('Invite candidates: search failed: $e');
      } finally {
        if (query.value == keyword) isSearching.value = false;
      }
    });
  }

  /// What the Recommended list shows right now.
  List<User> get recommendedVisible =>
      query.value.isEmpty ? recommended : searchResults;

  /// Friends filtered by the same search box (client-side).
  List<User> get friendsVisible {
    final q = query.value.toLowerCase();
    if (q.isEmpty) return friends;
    return friends
        .where((u) =>
            (u.username ?? '').toLowerCase().contains(q) ||
            (u.fullname ?? '').toLowerCase().contains(q))
        .toList();
  }
}
