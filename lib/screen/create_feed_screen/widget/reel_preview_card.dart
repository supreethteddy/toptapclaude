import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/session_manager.dart';
import 'package:toptap/common/widget/custom_blur_button.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/post_story/post_model.dart';
import 'package:toptap/screen/camera_screen/camera_types.dart';
import 'package:toptap/screen/create_feed_screen/create_feed_screen.dart';
import 'package:toptap/screen/create_feed_screen/create_feed_screen_controller.dart';
import 'package:toptap/screen/reels_screen/reels_screen.dart';

class ReelPreviewCard extends StatelessWidget {
  final CreateFeedScreenController controller;

  const ReelPreviewCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.createType != CreateFeedType.reel) {
      return const SizedBox();
    }
    return Container(
      width: 150,
      height: 235,
      margin: const EdgeInsets.only(top: 15),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipSmoothRect(
              radius: SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1),
              child: Obx(
                () => controller.content.value?.thumbnailBytes != null
                    ? Image.memory(controller.content.value!.thumbnailBytes!,
                        width: 150, height: 235, fit: BoxFit.cover)
                    : Container(),
              )),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CustomBlurButton(
                    onTap: () {
                      PostStoryContent? content = controller.content.value;
                      if (content == null) return;
                      Post reel = Post(
                          id: -1,
                          video: content.content,
                          userId: SessionManager.instance.getUserID(),
                          thumbnail: content.thumbNail,
                          user: SessionManager.instance.getUser());

                      Get.to(() => ReelsScreen(reels: [reel].obs, position: 0));
                    },
                    title: LKey.preview.tr),
                CustomBlurButton(
                    onTap: controller.onChangeReelCover,
                    title: LKey.changeCover.tr),
              ],
            ),
          )
        ],
      ),
    );
  }
}
