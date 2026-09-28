import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/common_extension.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/load_more_widget.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/reels_screen/reels_screen.dart';
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';
import 'package:super_context_menu/super_context_menu.dart';

class ReelList extends StatelessWidget {
  final RxList<Post> reels;
  final ScrollController? controller;
  final RxBool isLoading;
  final VoidCallback? onLoadMore;
  final bool isPinShow;
  final List<ContextMenuElement>? menus;
  final Future<void> Function() onFetchMoreData;
  final Function(dynamic)? onBackResponse;
  final bool shrinkWrap;
  final Widget? widget;

  const ReelList({
    super.key,
    required this.reels,
    this.controller,
    required this.isLoading,
    this.onLoadMore,
    this.isPinShow = false,
    this.menus,
    required this.onFetchMoreData,
    this.shrinkWrap = false,
    this.onBackResponse,
    this.widget,
  });

  @override
  Widget build(BuildContext context) {
    return LoadMoreWidget(
      loadMore: () async => onLoadMore?.call(),
      child: Obx(
        () => isLoading.value && reels.isEmpty
            ? const LoaderWidget()
            : NoDataView(
                title: LKey.noUserReelsTitle.tr,
                description: LKey.noUserReelsDescription.tr,
                showShow: !isLoading.value && reels.isEmpty,
                child: GridView.builder(
                    primary: !shrinkWrap,
                    shrinkWrap: shrinkWrap,
                    itemCount: reels.length,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 1,
                            crossAxisSpacing: 1,
                            mainAxisExtent: 172),
                    itemBuilder: (context, index) {
                      Post post = reels[index];
                      return ReelGridCardView(
                        onTap: () {
                          Get.to(
                                  () => ReelsScreen(
                                      reels: reels,
                                      position: index,
                                      onFetchMoreData: onFetchMoreData,
                                      widget: widget),
                                  preventDuplicates: false)
                              ?.then((value) {
                            onBackResponse?.call(value);
                          });
                        },
                        post: post,
                        isPinShow: isPinShow,
                        menus: menus,
                      );
                    }),
              ),
      ),
    );
  }
}

class ReelGridCardView extends StatelessWidget {
  final Post? post;
  final VoidCallback? onTap;
  final bool isPinShow;
  final List<ContextMenuElement>? menus;

  const ReelGridCardView(
      {super.key, this.post, this.onTap, this.isPinShow = false, this.menus});

  @override
  Widget build(BuildContext context) {
    return ContextMenuWidget(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: AlignmentDirectional.bottomEnd,
          children: [
            CustomImage(
                size: const Size(172, 172),
                strokeWidth: 0,
                image: post?.thumbnail?.addBaseURL(),
                radius: 0,
                isShowPlaceHolder: true),
            if (post?.isPinned == 1 && isPinShow)
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Image.asset(
                    AssetRes.icPinned,
                    width: 19,
                    height: 19,
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      AssetRes.icEye_2,
                      height: 15,
                      width: 18,
                      color: ColorRes.likeRed,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      (post?.views?.toInt() ?? 0).numberFormat,
                      style: TextStyleCustom.outFitMedium500(
                        fontSize: 13,
                        color: whitePure(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      menuProvider: (_) {
        if (menus == null || post == null) return Menu(children: []);

        // Pass the post instance into the menu items if required
        return Menu(
          children: menus!.map((element) {
            return MenuAction(
              title: element.title.isEmpty
                  ? (post?.isPinned == 1 ? LKey.unpin.tr : LKey.pin.tr)
                  : element.title,
              callback: () {
                element.onTap?.call(post!); // Pass the post to menu action
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class ContextMenuElement {
  final String title;
  final IconData? icon;
  final Function(Post post)? onTap; // Accepts Post

  ContextMenuElement({required this.title, this.icon, this.onTap});
}
