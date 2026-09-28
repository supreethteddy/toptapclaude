import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/widget/custom_search_text_field.dart';
import 'package:shortzz/common/widget/custom_tab_switcher.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/screen/music_sheet/music_sheet_controller.dart';
import 'package:shortzz/screen/music_sheet/widget/music_category_grid_view.dart';
import 'package:shortzz/screen/music_sheet/widget/music_list.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Full-screen "Sounds" picker used when attaching music to a reel/story.
class MusicSheet extends StatelessWidget {
  final int videoDurationInSecond;

  const MusicSheet({super.key, required this.videoDurationInSecond});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
        MusicSheetController(videoDurationInSecond));
    return Scaffold(
      backgroundColor: adaptiveBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            const _SoundsHeader(),
            CustomTabSwitcher(
                onTap: controller.onChangedMusicCategories,
                selectedIndex:
                    controller.selectedMusicCategory,
                items: controller.categories,
                margin: const EdgeInsets.symmetric(
                    horizontal: 10)),
            Row(
              children: [
                Expanded(
                  child: CustomSearchTextField(
                    controller: controller.searchController,
                    onTap: controller.onSearchTap,
                    onChanged: controller.onChanged,
                    onTapOutside: controller.onTapOutside,
                  ),
                ),
                Obx(
                  () => controller.isSearch.value
                      ? InkWell(
                          onTap: controller.onCancelTap,
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                              child: Text(LKey.cancel.tr,
                                  style: TextStyleCustom
                                      .outFitRegular400(
                                          fontSize: 15,
                                          color:
                                              textLightGrey(
                                                  context)))),
                        )
                      : const SizedBox(),
                )
              ],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Obx(
                  () => Stack(
                    children: [
                      PageView(
                        controller: controller.pageController,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        children: [
                          MusicList(
                              musicList: controller
                                  .exploreMusicList),
                          MusicCategoryGrid(
                              musicCategories: controller
                                  .musicCategoryList),
                          MusicList(
                              musicList:
                                  controller.savedMusicList),
                        ],
                      ),
                      if (controller.isSearch.value)
                        MusicList(
                            musicList:
                                controller.searchMusicList),
                      if (controller.isMusicDownloading.value)
                        const LoaderWidget()
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SoundsHeader extends StatelessWidget {
  const _SoundsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 15, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => Get.back(),
            child: Image.asset(
              AssetRes.icClose,
              height: 22,
              width: 22,
              color: ColorRes.likeRed,
            ),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AssetRes.icMusic,
                    height: 18,
                    width: 18,
                    color: ColorRes.likeRed,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    LKey.sounds.tr,
                    style: TextStyleCustom.unboundedRegular400(
                        color: textDarkGrey(context),
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 22),
        ],
      ),
    );
  }
}
