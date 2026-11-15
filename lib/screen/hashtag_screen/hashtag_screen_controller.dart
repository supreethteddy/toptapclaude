import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/service/api/post_service.dart';
import 'package:toptap/model/post_story/post/hashtag_post_model.dart';
import 'package:toptap/model/post_story/post_model.dart';

class HashtagScreenController extends BaseController {
  RxInt selectedTabIndex = 0.obs;
  String hashTag;

  late final PageController pageController;
  HashTag posts = HashTag(<Post>[].obs, 0.obs);
  HashTag reels = HashTag(<Post>[].obs, 0.obs);
  RxBool isReelLoading = false.obs;
  RxBool isPostLoading = false.obs;

  HashtagScreenController(this.hashTag) {
    pageController = PageController();
    selectedTabIndex.value = 0;
  }

  @override
  void onReady() {
    super.onReady();
    initData();
  }

  onChangeTab(int index) {
    selectedTabIndex.value = index;
  }

  Future<void> initData() async {
    final result = await Future.wait({
      fetchReels(),
      fetchPosts(),
    });
    List<Post> reels = result[0];
    List<Post> posts = result[1];

    if (reels.isEmpty && posts.isNotEmpty) {
      pageController.animateToPage(1,
          duration: const Duration(milliseconds: 300), curve: Curves.linear);
    }
  }

  Future<List<Post>> fetchReels() async {
    isReelLoading.value = true;
    HashtagPostData? _post = await PostService.instance.fetchPostsByHashtag(
        type: PostType.reels,
        hashTag: hashTag.removeHash,
        lastItemId: reels.post.lastOrNull?.id?.toInt());
    isReelLoading.value = false;
    if (_post != null) {
      reels.post.addAll(_post.posts ?? []);
      reels.postCount.value = _post.hashtag?.postCount?.toInt() ?? 0;
    }
    return reels.post;
  }

  Future<List<Post>> fetchPosts() async {
    isPostLoading.value = true;
    HashtagPostData? _post = await PostService.instance.fetchPostsByHashtag(
        type: PostType.posts,
        hashTag: hashTag.removeHash,
        lastItemId: posts.post.lastOrNull?.id?.toInt());
    isPostLoading.value = false;
    if (_post != null) {
      posts.post.addAll(_post.posts ?? []);
      posts.postCount.value = _post.hashtag?.postCount?.toInt() ?? 0;
    }
    return posts.post;
  }
}

class HashTag {
  RxList<Post> post;
  RxInt postCount;

  HashTag(this.post, this.postCount);
}
