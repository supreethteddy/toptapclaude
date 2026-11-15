import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:toptap/common/widget/custom_app_bar.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/common/widget/search_result_tile.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/common/widget/user_list.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/model/post_story/hashtag_model.dart';
import 'package:toptap/model/post_story/post_model.dart';
import 'package:toptap/model/user_model/user_model.dart';
import 'package:toptap/screen/camera_screen/camera_types.dart';
import 'package:toptap/screen/create_feed_screen/create_feed_screen_controller.dart';
import 'package:toptap/screen/create_feed_screen/widget/create_feed_location_bar.dart';
import 'package:toptap/screen/create_feed_screen/widget/feed_comment_toggle.dart';
import 'package:toptap/screen/create_feed_screen/widget/feed_image_view.dart';
import 'package:toptap/screen/create_feed_screen/widget/feed_text_field_view.dart';
import 'package:toptap/screen/create_feed_screen/widget/feed_video_view.dart';
import 'package:toptap/screen/create_feed_screen/widget/reel_preview_card.dart';
import 'package:toptap/screen/create_feed_screen/widget/url_meta_data_card.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/theme_res.dart';

enum CreateFeedType { feed, reel }

class CreateFeedScreen extends StatelessWidget {
  final CreateFeedType createType;
  final PostStoryContent? content;
  final Function({Post? post, CreateFeedType? type})? onAddPost;
  // CRITICAL FIX: Add optional video editing data
  final dynamic videoEditingController;

  const CreateFeedScreen(
      {super.key,
      required this.createType,
      this.onAddPost,
      this.content,
      this.videoEditingController});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CreateFeedScreenController(
        onAddPost, createType, content.obs, videoEditingController));

    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(
            title: createType == CreateFeedType.reel
                ? 'Create Reel'
                : LKey.createFeed.tr,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  controller.commentHelper.detectableTextFocusNode.unfocus(),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        // 1. Image/Video at the top (smaller size)
                        Obx(
                          () => switch (controller.feedPostType.value) {
                            FeedPostType.text => const SizedBox(),
                            FeedPostType.image => FeedImageView(
                                files: controller.images,
                                controller: controller),
                            FeedPostType.video =>
                              FeedVideoView(controller: controller),
                          },
                        ),

                        // 2. Media selection for feed (if no media selected)
                        if (createType == CreateFeedType.feed)
                          mediaSelectionView(controller),

                        const SizedBox(height: 8),

                        // 3. Caption/Text field with mentions and hashtags
                        const FeedTextFieldView(),

                        // 4. Location bar
                        CreateFeedLocationBar(controller: controller),

                        // 5. URL metadata if detected
                        UrlMetaDataCard(controller: controller),

                        // 6. Reel preview card (for reels only)
                        ReelPreviewCard(controller: controller),

                        // 7. Allow comments toggle
                        const FeedCommentToggle(),

                        const SizedBox(height: 16),

                        // 8. Upload button
                        _uploadButton(controller, context),
                      ],
                    ),
                  ),
                  Obx(() => mentionOrHashtagView(controller, context)),

                  // Floating video preview (when keyboard is open and video exists)
                  Obx(() => _buildFloatingVideoPreview(controller, context)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget mediaSelectionView(CreateFeedScreenController controller) {
    return Obx(
        () => controller.images.isNotEmpty || controller.video.value != null
            ? const SizedBox()
            : Row(
                children: [
                  BuildImageContainer(
                      image: AssetRes.icImage,
                      onTap: () => controller.onMediaTap(FeedPostType.image)),
                  const SizedBox(width: 5),
                  BuildImageContainer(
                      image: AssetRes.icVideo,
                      onTap: () => controller.onMediaTap(FeedPostType.video)),
                ],
              ));
  }

  Widget _uploadButton(
      CreateFeedScreenController controller, BuildContext context) {
    return Obx(() {
      final isUploading = controller.isUploadingPost.value;
      final uploadProgress = controller.progress.value.toInt();
      RxBool isEmpty = (createType == CreateFeedType.feed &&
              controller.commentHelper.isDetectableTextEmpty.value &&
              controller.feedPostType.value == FeedPostType.text)
          .obs;
      final buttonDisabled = isEmpty.value || isUploading;
      final buttonTitle =
          isUploading ? 'Uploading $uploadProgress%' : LKey.uploadNow.tr;

      return TextButtonCustom(
        onTap: buttonDisabled ? () {} : controller.handleUpload,
        title: buttonTitle,
        backgroundColor:
            textDarkGrey(context).withValues(alpha: buttonDisabled ? .5 : 1),
        titleColor:
            whitePure(context).withValues(alpha: buttonDisabled ? .5 : 1),
        borderSide: BorderSide(
            color:
                whitePure(context).withValues(alpha: buttonDisabled ? .5 : 1),
            width: 1),
        margin: EdgeInsets.symmetric(
            vertical: AppBar().preferredSize.height, horizontal: 20),
      );
    });
  }

  Widget mentionOrHashtagView(
      CreateFeedScreenController controller, BuildContext context) {
    if (!controller.commentHelper.isMentionUserView.value &&
        !controller.commentHelper.isHashTagView.value) {
      return const SizedBox();
    }
    final bool isMentionView = controller.commentHelper.isMentionUserView.value;
    final items = isMentionView
        ? controller.commentHelper.searchUsers
        : controller.commentHelper.hashTags;

    itemBuilder(context, index) {
      final item = items[index];
      if (isMentionView) {
        User user = item as User;
        return UserCard(
          onTap: () => controller.commentHelper
              .appendDetection(user, DetectType.atSign, type: 1),
          fullName: user.fullname,
          profilePhoto: user.profilePhoto,
          userName: user.username,
        );
      }
      Hashtag hashtag = item as Hashtag;
      return SearchResultTile(
        description: '${hashtag.postCount} ${LKey.posts.tr}',
        title: '${AppRes.hash}${hashtag.hashtag ?? ' '}',
        onTap: () => controller.commentHelper
            .appendDetection(hashtag, DetectType.hashTag, type: 1),
        image: AssetRes.icHashtag,
      );
    }

    return Container(
      color: (!controller.commentHelper.isLoading.value && items.isEmpty)
          ? null
          : bgLightGrey(context),
      height: double.infinity,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 180),
      child: controller.commentHelper.isLoading.value
          ? const LoaderWidget()
          : items.isEmpty
              ? const SizedBox()
              : ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.only(top: 5, left: 13, right: 13),
                  itemBuilder: itemBuilder),
    );
  }

  /// Build floating video preview that appears when keyboard is open
  Widget _buildFloatingVideoPreview(
      CreateFeedScreenController controller, BuildContext context) {
    // Only show if we have a video and text field is focused
    if (controller.feedPostType.value != FeedPostType.video ||
        controller.video.value == null ||
        !controller.commentHelper.detectableTextFocusNode.hasFocus) {
      return const SizedBox.shrink();
    }

    VideoPlayerController? playerController =
        controller.videoPlayerController.value;
    if (playerController == null) {
      return const SizedBox.shrink();
    }
    // Define a fixed width and calculate the height based on the video's aspect ratio
    final double previewWidth = 120;
    final double videoAspectRatio = playerController.value.aspectRatio;

    // The height should be calculated to maintain the original aspect ratio
    // height = width / aspectRatio
    final double previewHeight = previewWidth / videoAspectRatio;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60, // Below app bar
      right: 16,
      child: Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Video player
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter:
                      ColorFilter.matrix(controller.video.value!.colorFilter),
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: playerController.value.size.width,
                        height: playerController.value.size.height,
                        child: VideoPlayer(playerController),
                      ),
                    ),
                  ),
                ),
              ),
              // Play/pause overlay - FIXED: Only cover center area, not entire video
              Positioned.fill(
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: playerController,
                    builder: (context, value, child) {
                      return GestureDetector(
                        onTap: () {
                          if (value.isPlaying) {
                            playerController.pause();
                          } else {
                            playerController.play();
                          }
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Close button
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    controller.commentHelper.detectableTextFocusNode.unfocus();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuildImageContainer extends StatelessWidget {
  final String image;
  final VoidCallback onTap;

  const BuildImageContainer(
      {super.key, required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 59,
          decoration: BoxDecoration(color: bgLightGrey(context)),
          child: Center(
            child: Image.asset(image,
                color: textDarkGrey(context), height: 29, width: 29),
          ),
        ),
      ),
    );
  }
}
