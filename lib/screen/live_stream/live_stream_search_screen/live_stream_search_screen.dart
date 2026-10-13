import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/extensions/string_extension.dart';
import 'package:shortzz/common/widget/custom_image.dart';
import 'package:shortzz/common/widget/custom_search_text_field.dart';
import 'package:shortzz/common/widget/live_ring_avatar.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/no_data_widget.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/livestream/app_user.dart';
import 'package:shortzz/model/livestream/livestream.dart';
import 'package:shortzz/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:shortzz/screen/live_stream/discover_live/live_discovery_feed_screen.dart'
    show LiveDiscoveryPreviewCard;
import 'package:shortzz/screen/live_stream/live_stream_search_screen/live_stream_search_screen_controller.dart';
import 'package:shortzz/screen/reels_screen/reels_screen.dart'
    show CustomPageViewScrollPhysics;
import 'package:shortzz/utilities/asset_res.dart';
import 'package:shortzz/utilities/color_res.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class LiveStreamSearchScreen extends StatelessWidget {
  const LiveStreamSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LiveStreamSearchScreenController());
    return Scaffold(
      backgroundColor: adaptiveBackground(context),
      body: Stack(
        children: [
          //  const LiveStreamBlurBackgroundImage(),
          Column(
            children: [
              const LiveStreamSearchTopView(),
              LiveStreamAvatarCarousel(controller: controller),
              CustomSearchTextField(
                onChanged: controller.onSearchChange,
                backgroundColor: adaptiveBackground(context),
                borderSide: BorderSide(
                    color: adaptiveBorderColor(context).withValues(alpha: .18)),
              ),
              LiveStreamListView(controller: controller),
            ],
          ),
        ],
      ),
    );
  }
}

class LiveStreamSearchTopView extends StatelessWidget {
  const LiveStreamSearchTopView({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.symmetric(vertical: 20),
      child: Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          Align(
            alignment: Alignment.center,
            child: FittedBox(
              child: Container(
                height: 30,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 30, cornerSmoothing: 0),
                      side: BorderSide(
                          color: whitePure(context).withValues(alpha: .3),
                          width: 1),
                      borderAlign: BorderAlign.inside),
                  color: ColorRes.textStoryBgGradient2,
                ),
                child: Row(
                  children: [
                    Image.asset(AssetRes.icLive,
                        color: whitePure(context), height: 22, width: 22),
                    const SizedBox(width: 5),
                    Text(
                      LKey.livestreams.tr.toUpperCase(),
                      style: TextStyleCustom.unboundedRegular400(
                        fontSize: 12,
                        color: whitePure(context),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Get.to(() => const CreateLiveStreamScreen());
            },
            child: Container(
              height: 30,
              margin: const EdgeInsets.only(top: 10, right: 10, left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: ShapeDecoration(
                  color: adaptiveBackground(context),
                  shape: SmoothRectangleBorder(
                      side: BorderSide(color: adaptiveBorderColor(context)),
                      borderRadius: SmoothBorderRadius(
                          cornerRadius: 30, cornerSmoothing: 1))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AssetRes.icLive_1,
                    color: ColorRes.likeRed,
                    width: 25,
                    height: 25,
                  ),
                  Text(
                    LKey.goLive.tr,
                    style: TextStyleCustom.unboundedRegular400(
                        color: ColorRes.green1, fontSize: 12),
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

/// Horizontal, scrollable row of circular avatars for every currently-live
/// host, so viewers can quickly jump between live rooms (mirrors the avatar
/// strip on TikTok's "Discover LIVE" screen). Tapping an avatar opens that
/// stream via the same [LiveStreamSearchScreenController.onLiveUserTap]
/// used by the list below.
class LiveStreamAvatarCarousel extends StatelessWidget {
  final LiveStreamSearchScreenController controller;

  const LiveStreamAvatarCarousel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final streams = controller.livestreamFilterList;
      if (streams.isEmpty) return const SizedBox();
      return SizedBox(
        height: 96,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            Livestream stream = streams[index];
            AppUser? hostUser = stream
                .getHostUser(controller.firebaseFirestoreController.users);
            return InkWell(
              onTap: () => controller.onLiveUserTap(stream),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LiveRingAvatar(
                      userId: hostUser?.userId,
                      onLiveTap: () => controller.onLiveUserTap(stream),
                      showLabel: false,
                      child: CustomImage(
                        size: const Size(60, 60),
                        image: hostUser?.profile?.addBaseURL(),
                        fullName: hostUser?.fullname,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        hostUser?.username ?? '',
                        style: TextStyleCustom.outFitRegular400(
                            fontSize: 11, color: whitePure(context)),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

/// Full 9:16, Reels-style vertical swipe feed of the current search
/// results — replaces the old short (310px) fixed-height grid cards.
/// Reuses the exact same full-bleed LiveDiscoveryPreviewCard the main LIVE
/// icon's LiveDiscoveryFeedScreen uses, so both "browse who's LIVE"
/// entry points look identical; this one is sourced from
/// [controller.livestreamFilterList] instead of LiveStatusController so it
/// reflects the current search-bar filter. Tapping a card keeps this
/// screen's existing immediate-join behaviour (onLiveUserTap) — unchanged.
class LiveStreamListView extends StatelessWidget {
  final LiveStreamSearchScreenController controller;

  const LiveStreamListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Obx(() {
        final streams = controller.livestreamFilterList;
        if (controller.isLoading.value && streams.isEmpty) {
          return const LoaderWidget();
        }
        if (streams.isEmpty) {
          return NoDataView(
            showShow: true,
            title: LKey.noLivestreamsTitle,
            description: LKey.noLivestreamsDescription.tr,
            child: const SizedBox(),
          );
        }
        return PageView.builder(
          scrollDirection: Axis.vertical,
          physics: const CustomPageViewScrollPhysics(),
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            return LiveDiscoveryPreviewCard(
              room: stream,
              onTap: () => controller.onLiveUserTap(stream),
            );
          },
        );
      }),
    );
  }
}
