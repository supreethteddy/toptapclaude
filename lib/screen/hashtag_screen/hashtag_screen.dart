import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/extensions/common_extension.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/custom_tab_switcher.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/common/widget/post_list.dart';
import 'package:toptap/common/widget/reel_list.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/screen/hashtag_screen/hashtag_screen_controller.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class HashtagScreen extends StatelessWidget {
  final String hashtag;

  const HashtagScreen({super.key, required this.hashtag});

  @override
  Widget build(BuildContext context) {
    // Every time data reload
    final controller = Get.put(HashtagScreenController(hashtag),
        tag: '${DateTime.now().millisecondsSinceEpoch}');
    return Scaffold(
      body: Column(
        children: [
          Obx(
            () => CustomAppBar(
                title: hashtag.addHash,
                subTitle:
                    '${(controller.selectedTabIndex.value == 0 ? controller.posts.postCount : controller.reels.postCount).value.numberFormat} ${LKey.posts.tr}',
                titleStyle: TextStyleCustom.unboundedSemiBold600(
                    fontSize: 15, color: textDarkGrey(context)),
                widget: CustomTabSwitcher(
                  items: [(LKey.reels.tr), (LKey.feed.tr)],
                  selectedIndex: controller.selectedTabIndex,
                  margin:
                      const EdgeInsets.only(bottom: 15, left: 15, right: 15),
                  onTap: (index) {
                    controller.onChangeTab(index);
                    controller.pageController.animateToPage(index,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.linear);
                  },
                )),
          ),
          Expanded(
            child: Obx(
              () => controller.isLoading.value &&
                      (controller.selectedTabIndex.value == 0
                          ? controller.posts.post.isEmpty
                          : controller.reels.post.isEmpty)
                  ? const LoaderWidget()
                  : PageView(
                      controller: controller.pageController,
                      onPageChanged: controller.onChangeTab,
                      children: [
                        ReelList(
                          reels: controller.reels.post,
                          isLoading: controller.isReelLoading,
                          onFetchMoreData: controller.fetchReels,
                          widget: Text(
                            hashtag,
                            style: TextStyleCustom.unboundedSemiBold600(
                                color: whitePure(context), fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PostList(
                          posts: controller.posts.post,
                          isLoading: controller.isPostLoading,
                          onFetchMoreData: controller.fetchPosts,
                        ),
                      ],
                    ),
            ),
          )
        ],
      ),
    );
  }
}
