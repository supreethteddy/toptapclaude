import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shortzz/common/controller/follow_controller.dart';
import 'package:shortzz/common/controller/profile_controller.dart';
import 'package:shortzz/common/enum/chat_enum.dart';
import 'package:shortzz/common/extensions/list_extension.dart';
import 'package:shortzz/common/extensions/user_extension.dart';
import 'package:shortzz/common/manager/logger.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/common/service/api/moderator_service.dart';
import 'package:shortzz/common/service/api/post_service.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/widget/confirmation_dialog.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/chat/chat_thread.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/model/post_story/story/story_model.dart';
import 'package:shortzz/model/post_story/user_post_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/screen/blocked_user_screen/block_user_controller.dart';
import 'package:shortzz/screen/chat_screen/chat_screen.dart';
import 'package:shortzz/screen/create_feed_screen/create_feed_screen.dart';
import 'package:shortzz/screen/post_screen/post_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:shortzz/screen/report_sheet/report_sheet.dart';
import 'package:shortzz/screen/story_view_screen/story_view_screen.dart';
import 'package:shortzz/utilities/app_res.dart';

class ProfileScreenController extends BlockUserController
    with GetTickerProviderStateMixin {
  static const tag = 'PROFILE';
  late final GlobalKey<ScaffoldState> scaffoldKey;

  RxInt selectedTabIndex = 0.obs;

  Rx<User?> userData;
  RxList<Post> reels = <Post>[].obs;
  RxList<Post> posts = <Post>[].obs;
  // adding new tabs
  RxList<Post> lockedPosts = <Post>[].obs;
  RxList<Post> favoritePosts = <Post>[]
      .obs; // Now used for Saved (moved from savedPosts)
  RxList<Post> savedPosts = <Post>[]
      .obs; // Now used for Favorites (moved from favoritePosts)
  RxList<Post> draftPosts =
      <Post>[].obs; // New: Draft posts

  RxBool isReelLoading = false.obs;
  RxBool isPostLoading = false.obs;
  // Add new Controller
  RxBool isLockedLoading = false.obs;
  RxBool isFavoriteLoading = false.obs;
  RxBool isSavedLoading = false.obs;
  RxBool isDraftLoading =
      false.obs; // New: Draft loading state
  // Add new Controller
  final PageController pageController = PageController();
  late TabController tabController;
  RxBool isUserNotFound = false.obs;
  Setting? settingData =
      SessionManager.instance.getSettings();
  bool isFollowUnFollowInProcess = false;
  late ProfileController profileController;
  final Function(User? user)? onUserUpdate;

  ProfileScreenController(
      this.userData, this.onUserUpdate) {
    // Create unique scaffold key for each profile instance
    scaffoldKey = GlobalKey<ScaffoldState>(
        debugLabel:
            'ProfileScaffold_${userData.value?.id ?? DateTime.now().millisecondsSinceEpoch}');
  }

  // Check if viewing own profile
  bool get isOwnProfile =>
      userData.value?.id ==
      SessionManager.instance.getUserID();

  // Get number of tabs based on profile type
  int get tabLength => isOwnProfile ? 5 : 2;

  @override
  void onInit() {
    super.onInit();

    // Initialize TabController with dynamic tab count (2 for others, 5 for own profile)
    tabController =
        TabController(length: tabLength, vsync: this);

    if (Get.isRegistered<ProfileController>(
        tag: '${userData.value?.id}')) {
      profileController = Get.find<ProfileController>(
          tag: '${userData.value?.id}');
      userData.value = profileController.user;
    } else {
      profileController = Get.put(
          ProfileController(userData.value),
          tag: '${userData.value?.id}');
    }
    userData.listen((p0) {
      if (p0 != userData.value) {
        onUserUpdate?.call(p0);
      }
    });

    // Add listener to update tab index when page is swiped
    pageController.addListener(() {
      if (pageController.page != null) {
        final page = pageController.page!.round();
        if (selectedTabIndex.value != page) {
          selectedTabIndex.value = page;
          onTabChanged(page);
          // Sync TabController with PageController
          if (tabController.index != page) {
            tabController.animateTo(page);
          }
        }
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    iniData();
  }

  @override
  void onClose() {
    pageController.dispose();
    tabController.dispose();
    super.onClose();
  }

  iniData() {
    Future.wait({
      fetchUserDetail(),
      fetchReel(),
      fetchPost(),
    });
  }

  void onTabChanged(int value) {
    selectedTabIndex.value = value;

    // Load data for specific tabs when they're accessed
    switch (value) {
      case 2: // Private/Locked tab
        if (lockedPosts.isEmpty && !isLockedLoading.value) {
          fetchLocked(isEmpty: true);
        }
        break;
      case 3: // Saved tab
        if (savedPosts.isEmpty && !isSavedLoading.value) {
          fetchSaved(isEmpty: true);
        }
        break;
      case 4: // Draft tab
        if (draftPosts.isEmpty && !isDraftLoading.value) {
          fetchDrafts(isEmpty: true);
        }
        break;
    }
  }

  Future<void> fetchUserDetail() async {
    isLoading.value = true;
    User? user = await UserService.instance
        .fetchUserDetails(
            userId: userData.value?.id?.toInt());
    profileController.updateUser(user);
    isLoading.value = false;
    if (user != null) {
      userData.value = user;
    } else {
      isUserNotFound.value = true;
    }
  }

  Future<void> fetchReel({bool isEmpty = false}) async {
    if (isReelLoading.value) return;
    isReelLoading.value = true;
    try {
      UserPostData? items = await PostService.instance
          .fetchUserPosts(
              type: PostType.reels,
              userId: userData.value?.id?.toInt(),
              lastItemId: isEmpty
                  ? null
                  : reels.lastOrNull?.id?.toInt());
      if (isEmpty) reels.clear();

      if (reels.isEmpty) {
        reels.addAll(items?.pinnedPostList ?? []);
      }

      for (var post in (items?.posts ?? [])) {
        if (reels.firstWhereOrNull(
                (element) => element.id == post.id) ==
            null) {
          reels.add(post);
        }
      }
    } catch (e) {
      Loggers.error('Fetch Reel Error : $e');
    } finally {
      isReelLoading.value = false;
    }
  }

  Future<void> fetchPost({bool isEmpty = false}) async {
    if (isPostLoading.value) return;
    isPostLoading.value = true;
    // Fetch user posts
    UserPostData? items =
        await PostService.instance.fetchUserPosts(
      type: PostType.posts,
      userId: userData.value?.id?.toInt() ??
          SessionManager.instance.getUserID(),
      lastItemId:
          isEmpty ? null : posts.lastOrNull?.id?.toInt(),
    );

    if (isEmpty) {
      posts.clear();
    }
    if (posts.isEmpty) {
      posts.addAll(items?.pinnedPostList ?? []);
    }

    for (var post in (items?.posts ?? [])) {
      if (posts.firstWhereOrNull(
              (element) => element.id == post.id) ==
          null) {
        posts.add(post);
      }
    }
    isPostLoading.value = false;
    posts.refresh();
  }

  // Controllers of new tabs

  Future<void> fetchLocked({bool isEmpty = false}) async {
    if (isLockedLoading.value) return;
    isLockedLoading.value = true;
    try {
      // Only show locked content if viewing own profile
      bool isMyProfile = userData.value?.id ==
          SessionManager.instance.getUserID();

      if (!isMyProfile) {
        // Don't show private posts to other users
        lockedPosts.clear();
        isLockedLoading.value = false;
        return;
      }

      // TODO: Backend needs to implement fetchPrivatePosts API
      // For now, filter posts with isPrivate field or specific criteria
      UserPostData? items =
          await PostService.instance.fetchUserPosts(
        type: PostType.posts,
        userId: userData.value?.id?.toInt(),
        lastItemId: isEmpty
            ? null
            : lockedPosts.lastOrNull?.id?.toInt(),
      );

      if (isEmpty) lockedPosts.clear();

      if (lockedPosts.isEmpty) {
        lockedPosts.addAll(items?.pinnedPostList ?? []);
      }

      // Filter for private/locked posts (assuming a field exists)
      for (var post in (items?.posts ?? [])) {
        // TODO: Check if post has isPrivate field or similar
        // For now, add posts that are marked as private (if field exists)
        if (lockedPosts
                .firstWhereOrNull((e) => e.id == post.id) ==
            null) {
          // Add logic here to check if post is private
          // Example: if (post.isPrivate == 1)
          lockedPosts.add(post);
        }
      }
    } catch (e) {
      Loggers.error('Fetch Locked Error : $e');
    } finally {
      isLockedLoading.value = false;
    }
  }

  Future<void> fetchFavorites(
      {bool isEmpty = false}) async {
    if (isFavoriteLoading.value) return;
    isFavoriteLoading.value = true;
    try {
      if (isEmpty) favoritePosts.clear();

      // 🔄 WORKAROUND: Use local storage for liked posts
      // Get liked post IDs from local storage
      final likedPostIds = _getLikedPostIds();

      if (likedPostIds.isEmpty) {
        // No liked posts found
        isFavoriteLoading.value = false;
        return;
      }

      // Fetch recent posts and reels to check against liked IDs
      UserPostData? postsData =
          await PostService.instance.fetchUserPosts(
        type: PostType.posts,
        userId: userData.value?.id?.toInt(),
        lastItemId: null, // Get recent posts
      );

      UserPostData? reelsData =
          await PostService.instance.fetchUserPosts(
        type: PostType.reels,
        userId: userData.value?.id?.toInt(),
        lastItemId: null, // Get recent reels
      );

      // Also fetch from dashboard/explore to get posts user has liked
      // This is more comprehensive than just user's own posts
      List<Post> allPosts = [];
      allPosts.addAll(postsData?.posts ?? []);
      allPosts.addAll(reelsData?.posts ?? []);

      // Filter posts that are in our liked list
      for (var post in allPosts) {
        if (likedPostIds.contains(post.id) &&
            favoritePosts.firstWhereOrNull(
                    (e) => e.id == post.id) ==
                null) {
          favoritePosts.add(post);
        }
      }

      // Sort by most recently liked (based on local storage timestamp)
      favoritePosts.sort((a, b) =>
          _getLikeTimestamp(b.id ?? 0)
              .compareTo(_getLikeTimestamp(a.id ?? 0)));
    } catch (e) {
      Loggers.error('Fetch Favorites Error : $e');
    } finally {
      isFavoriteLoading.value = false;
    }
  }

  // 📱 Helper methods for local storage management
  List<int> _getLikedPostIds() {
    try {
      final storage = GetStorage('shortzz');
      final likedIds =
          storage.read<List>('liked_post_ids') ?? [];
      return likedIds.cast<int>();
    } catch (e) {
      Loggers.error('Error reading liked post IDs: $e');
      return [];
    }
  }

  int _getLikeTimestamp(int postId) {
    try {
      final storage = GetStorage('shortzz');
      final timestamps =
          storage.read<Map>('like_timestamps') ?? {};
      return timestamps[postId.toString()] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> fetchSaved({bool isEmpty = false}) async {
    if (isSavedLoading.value) return;
    isSavedLoading.value = true;
    try {
      if (isEmpty) savedPosts.clear();

      // Fetch both saved posts and saved reels
      List<Post> savedPostsItems =
          await PostService.instance.fetchSavedPosts(
        type: PostType.posts,
        lastItemId: isEmpty
            ? null
            : savedPosts
                .where((p) => p.postType != PostType.reel)
                .lastOrNull
                ?.id
                ?.toInt(),
      );

      List<Post> savedReelsItems =
          await PostService.instance.fetchSavedPosts(
        type: PostType.reels,
        lastItemId: isEmpty
            ? null
            : savedPosts
                .where((p) => p.postType == PostType.reel)
                .lastOrNull
                ?.id
                ?.toInt(),
      );

      // Combine both lists
      List<Post> allSavedItems = [
        ...savedPostsItems,
        ...savedReelsItems
      ];

      for (var post in allSavedItems) {
        if (savedPosts
                .firstWhereOrNull((e) => e.id == post.id) ==
            null) {
          savedPosts.add(post);
        }
      }

      // Sort by creation date (most recent first)
      savedPosts.sort((a, b) =>
          (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    } catch (e) {
      Loggers.error('Fetch Saved Error : $e');
    } finally {
      isSavedLoading.value = false;
    }
  }

  Future<void> fetchDrafts({bool isEmpty = false}) async {
    if (isDraftLoading.value) return;
    isDraftLoading.value = true;
    try {
      if (isEmpty) draftPosts.clear();

      // For now, return empty list as draft functionality may not be fully implemented
      // This can be updated later when draft API is available

      // Sort by creation date (most recent first) when drafts are added
      draftPosts.sort((a, b) =>
          (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
    } catch (e) {
      Loggers.error('Fetch Drafts Error : $e');
    } finally {
      isDraftLoading.value = false;
    }
  }

  Future<void> onRefresh() async {
    Future.wait([
      fetchUserDetail(),
      fetchPost(isEmpty: true),
      fetchReel(isEmpty: true),
      fetchLocked(isEmpty: true),
      fetchFavorites(isEmpty: true),
      fetchSaved(isEmpty: true),
      fetchDrafts(isEmpty: true),
    ]);
  }

  void onAddPost({Post? post, CreateFeedType? type}) {
    if (post == null) return; // Exit early if post is null

    // Determine the target list based on the type
    List<Post> targetList =
        type == CreateFeedType.feed ? posts : reels;

    // Find the position to insert the post after pinned posts
    int pinnedCount = targetList
        .where((element) => element.isPinned == 1)
        .length;

    // Insert the post at the appropriate position
    targetList.insert(pinnedCount, post);
  }

  void onAddStory(Story? story) {
    if (story == null) {
      return; // Exit early if story is null
    }
    userData.update((val) {
      val?.stories?.add(story);
    });
  }

  Future<StatusModel> unpinPost(Post post) async {
    StatusModel response = await PostService.instance
        .unpinPost(postId: post.id?.toInt() ?? -1);
    return response;
  }

  Future<StatusModel> pinPost(Post post) async {
    StatusModel response = await PostService.instance
        .pinPost(postId: post.id?.toInt() ?? -1);
    return response;
  }

  onUpdateUser(User? user) {
    print('onUpdateUser called with user ${user?.id}');
    userData.value = user;
    userData.refresh();
  }

  void reportUser(User? user) {
    Get.bottomSheet(
        ReportSheet(
            id: user?.id, reportType: ReportType.user),
        isScrollControlled: true);
  }

  onPinUnpinReel(Post post) async {
    if (post.isPinned == 0) {
      List<Post> existingPinPost = [];

      for (var element in reels) {
        if (element.isPinned == 1) {
          existingPinPost.add(element);
        }
      }

      if ((settingData?.maxPostPins ?? AppRes.maxPinFeed) >
          existingPinPost.length) {
        StatusModel model = await pinPost(post);
        if (model.status == true) {
          reels.removeWhere(
              (element) => element.id == post.id);
          post.isPinned = 1;
          reels.insert(0, post);
          reels.refresh();
        }
      } else {
        // showSnackBar('You can maximum ${settingData.value?.maxPostPins} pinned');
        showSnackBar(LKey.pinLimitExceeded.trParams({
          'pin_count':
              '${settingData?.maxPostPins ?? AppRes.maxPinFeed.toString()}'
        }));
      }
    } else {
      StatusModel response = await unpinPost(post);
      if (response.status == true) {
        fetchReel(isEmpty: true);
      }
    }
  }

  onDeleteReel(Post post, {required bool isModerator}) {
    Get.bottomSheet(
      ConfirmationSheet(
          title: LKey.deletePostTitle.tr,
          onTap: () async {
            showLoader();
            StatusModel model;
            if (isModerator) {
              model = await ModeratorService.instance
                  .moderatorDeletePost(
                      postId: post.id?.toInt() ?? -1);
            } else {
              model = await PostService.instance.deletePost(
                  postId: post.id?.toInt() ?? -1);
            }
            if (model.status == true) {
              Get.delete<ReelController>(tag: '${post.id}');
              reels.removeWhere(
                  (element) => element.id == post.id);
              post = Post();
            }
            stopLoader();
          },
          description: LKey.deletePostMessage.tr),
    );
  }

  void toggleBlockUnblock(isBlock) {
    if (isBlock) {
      unblockUser(userData.value, () {
        userData
            .update((val) => val?.updateBlockStatus(false));
      });
    } else {
      blockUser(userData.value, () {
        userData.update(
          (val) {
            val?.updateBlockStatus(true);
          },
        );
      });
    }
  }

  updatePinPost(Post post) async {
    List<Post> existingPinPost = [];

    for (var element in posts) {
      if (element.isPinned == 1) {
        existingPinPost.add(element);
      }
    }

    if ((settingData?.maxPostPins ?? AppRes.maxPinFeed) >
        existingPinPost.length) {
      StatusModel response = await pinPost(post);
      if (response.status == true) {
        posts.removeWhere(
            (element) => element.id == post.id);
        post.isPinned = 1;
        final controller = Get.find<PostScreenController>(
            tag: '${post.id}');
        controller.updatePost(post);
        posts.insert(0, post);
        posts.refresh();
      }
    } else {
      // showSnackBar('You can maximum ${settingData.value?.maxPostPins} pinned');
      showSnackBar(LKey.pinLimitExceeded.trParams({
        'pin_count':
            '${settingData?.maxPostPins ?? AppRes.maxPinFeed.toString()}'
      }));
    }
  }

  updateUnPinPost(Post post) async {
    StatusModel response = await unpinPost(post);
    if (response.status == true) {
      final controller =
          Get.find<PostScreenController>(tag: '${post.id}');
      post.isPinned = 0;
      controller.updatePost(post);
      fetchPost(isEmpty: true);
    }
  }

  Future<void> followUnFollowUser() async {
    print(
        'Starting followUnFollowUser for user ${userData.value?.id}');
    int userId = userData.value?.id ?? -1;
    if (isFollowUnFollowInProcess) return;
    isFollowUnFollowInProcess = true;

    FollowController followController;
    if (Get.isRegistered<FollowController>(
        tag: userId.toString())) {
      followController = Get.find<FollowController>(
          tag: userId.toString());
      followController.updateUser(userData.value);
    } else {
      followController = Get.put(FollowController(userData),
          tag: userId.toString());
    }

    User? user =
        await followController.followUnFollowUser();
    isFollowUnFollowInProcess = false;
    userData.update((val) {
      val?.isFollowing = user?.isFollowing;
      val?.followerCount = user?.followerCount;
      val?.followingCount = user?.followingCount;
    });
    profileController.updateUser(userData.value);
  }

  void handlePublishOrMessageBtn(bool isMe) {
    if (isMe) {
      // Here we should share our profile link

      // Get.bottomSheet(PostOptionsSheet(controller: this),
      //     isScrollControlled: true);

      // Share your profile link
      final myUser = SessionManager.instance.getUser();
      final userId = myUser?.id;

      if (userId != null) {
        final profileLink =
            "_toptap://profile/$userId"; // Replace with your actual profile URL format
        Share.share(
            "Check out my profile on TopTap! 👇\n$profileLink");
      } else {
        print("User ID is null. Cannot share profile.");
      }
    } else {
      ChatThread conversation = ChatThread(
          id: DateTime.now()
              .millisecondsSinceEpoch
              .toString(),
          lastMsg: '',
          msgCount: 0,
          isDeleted: false,
          deletedId: 0,
          iAmBlocked: false,
          iBlocked: userData.value?.isBlock ?? false,
          requestType: UserRequestAction.accept.title,
          chatType: userData.value?.isFollowing ?? false
              ? ChatType.approved
              : ChatType.request,
          conversationId: [
            SessionManager.instance.getUserID(),
            userData.value?.id
          ].conversationId,
          userId: userData.value?.id);
      conversation.chatUser = userData.value?.appUser;
      Get.to(() => ChatScreen(
          conversationUser: conversation,
          user: userData.value));
    }
  }

  void onStoryTap(bool isStoryAvailable) {
    if (isStoryAvailable) {
      userData.value?.checkIsBlocked(() {
        Get.bottomSheet(
                StoryViewSheet(
                  stories: [userData.value!],
                  userIndex: 0,
                  onUpdateDeleteStory: (story) {
                    userData.update((val) =>
                        (val?.stories ?? []).removeWhere(
                            (element) =>
                                element.id == story?.id));
                  },
                ),
                isScrollControlled: true,
                ignoreSafeArea: false)
            .then((value) {
          // For check story view or not
          fetchUserDetail();
        });
      });
    }
  }

  void freezeUnfreezeUser(bool isFreeze) async {
    StatusModel result;
    showLoader();
    if (isFreeze) {
      result = await ModeratorService.instance
          .moderatorUnFreezeUser(
              userId: userData.value?.id);
    } else {
      result = await ModeratorService.instance
          .moderatorFreezeUser(userId: userData.value?.id);
    }
    stopLoader();

    if (result.status == true) {
      userData
          .update((val) => val?.isFreez = isFreeze ? 0 : 1);
    }
  }
}
