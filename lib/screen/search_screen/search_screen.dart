import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_back_button.dart';
import 'package:toptap/common/widget/custom_search_text_field.dart';
import 'package:toptap/common/widget/post_list.dart';
import 'package:toptap/common/widget/reel_list.dart';
import 'package:toptap/common/widget/search_result_tile.dart';
import 'package:toptap/common/widget/user_list.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/screen/create_feed_screen/widget/location_sheet.dart';
import 'package:toptap/screen/search_screen/search_screen_controller.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class SearchScreen extends StatelessWidget {
  final int? initialTabIndex;

  const SearchScreen({super.key, this.initialTabIndex});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SearchScreenController(
        initialTabIndex: initialTabIndex));
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: bgLightGrey(context),
            padding:
                const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CustomBackButton(
                                width: 18, height: 18),
                            Expanded(
                                child: Obx(
                              () => CustomSearchTextField(
                                controller: controller
                                    .searchKeyword,
                                onChanged: (value) =>
                                    controller
                                        .onChanged(600),
                                suffixIcon: controller
                                        .isTextEmpty.value
                                    ? null
                                    : InkWell(
                                        onTap: () {
                                          controller
                                              .searchKeyword
                                              .clear();
                                          controller
                                              .onChanged(0);
                                        },
                                        child: Image.asset(
                                            AssetRes
                                                .icClose,
                                            width: 20,
                                            height: 20,
                                            color:
                                                textLightGrey(
                                                    context)),
                                      ),
                              ),
                            ))
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceAround,
                  children: List.generate(
                    controller.searchTabs.length,
                    (index) {
                      SearchTabs tabs =
                          controller.searchTabs[index];
                      return InkWell(
                        onTap: () {
                          controller.pageController
                              .animateToPage(index,
                                  duration: const Duration(
                                      milliseconds: 300),
                                  curve: Curves.linear);
                        },
                        child: Obx(
                          () {
                            bool isSelected = controller
                                    .selectedTabIndex
                                    .value ==
                                tabs;
                            return Text(
                              tabs.title,
                              style: isSelected
                                  ? TextStyleCustom
                                      .outFitRegular400(
                                          fontSize: 15,
                                          color:
                                              textDarkGrey(
                                                  context))
                                  : TextStyleCustom
                                      .outFitLight300(
                                          fontSize: 15,
                                          color:
                                              textLightGrey(
                                                  context)),
                            );
                          },
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: controller.pageController,
              onPageChanged: controller.onSearchTabTap,
              children: [
                PostList(
                  posts: controller.posts,
                  isLoading: controller.isFeedLoading,
                  onFetchMoreData: controller.searchPosts,
                ),
                ReelList(
                  reels: controller.reels,
                  isLoading: controller.isReelsLoading,
                  onFetchMoreData: controller.searchPosts,
                ),
                UserList(
                  onTap: controller.onUserTap,
                  users: controller.users,
                  isLoading: controller.isUsersLoading,
                  loadMore: controller.searchUsers,
                  getFullName: (p0) => p0.fullname ?? '',
                  getProfilePhoto: (p0) =>
                      p0.profilePhoto ?? '',
                  getUserName: (p0) => p0.username ?? '',
                  getVerified: (p0) => p0.isVerify ?? 0,
                ),
                ImageTextListTile(
                  items: controller.hashtags,
                  onTap: controller.onHashTagTap,
                  image: AssetRes.icHashtag,
                  getDisplayText: (p0) =>
                      '${AppRes.hash}${p0.hashtag ?? ''}',
                  getDisplayDescription: (p0) =>
                      '${p0.postCount} ${LKey.posts.tr}',
                  isLoading: controller.isHashTagsLoading,
                  loadMore: controller.searchHashTags,
                ),
                Obx(
                  () => ImageTextListTile(
                    items: controller.places,
                    onTap: controller.onLocationTap,
                    image: AssetRes.icLocation,
                    getDisplayText: (p0) => p0.title,
                    getDisplayDescription: (p0) =>
                        p0.description,
                    isLoading: controller.isPlacesLoading,
                    noDataWidget:
                        controller.isLocationError.value
                            ? LocationErrorWidget(
                                showError: controller
                                    .isLocationError.value)
                            : null,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
