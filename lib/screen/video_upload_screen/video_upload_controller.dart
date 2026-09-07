import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shortzz/common/service/api/add_post_story_service.dart';
import 'package:shortzz/common/service/api/common_service.dart';
import 'package:shortzz/common/service/utils/params.dart';
import 'package:shortzz/model/general/file_path_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/camera_screen/camera_types.dart';
import 'package:shortzz/screen/comment_sheet/helper/comment_helper.dart';
import 'package:shortzz/screen/create_feed_screen/create_feed_screen.dart';
import 'package:shortzz/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:shortzz/screen/profile_screen/profile_screen_controller.dart';

/// 🎬 VideoUploadController - Controller for handling video uploads with burned-in edits
/// This controller is specifically designed for videos that have text, stickers, and drawings
/// already processed and burned into the video file.
class VideoUploadController extends GetxController {
  final String videoPath;
  final CreateFeedType createType;
  final Function({Post? post, CreateFeedType? type})?
      onAddPost;

  // Controllers and observables
  /// Caption field with @mention / #hashtag detection (same helper as the
  /// feed composer) so typing "@" shows user suggestions.
  final CommentHelper commentHelper = CommentHelper();

  TextEditingController get captionController =>
      commentHelper.detectableTextController;

  /// IDs of the users mentioned in the caption (resolved from the
  /// suggestion list the user picked from).
  List<int> get mentionedUserIds {
    final text = captionController.text;
    final names = RegExp(r'@([A-Za-z0-9_.]+)')
        .allMatches(text)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet();
    final ids = <int>[];
    for (final user in commentHelper.allMentionUsers) {
      final username = (user.username ?? '').toLowerCase();
      if (names.contains(username) && user.id != null) {
        ids.add(user.id!.toInt());
      }
    }
    return ids;
  }
  final RxBool isUploading = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxString uploadStatus = 'Ready to upload'.obs;
  final RxBool canComment =
      true.obs; // Allow comments by default

  VideoUploadController({
    required this.videoPath,
    required this.createType,
    this.onAddPost,
  });

  @override
  void onInit() {
    super.onInit();
    _validateVideoFile();
  }

  void _validateVideoFile() {
    try {
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        throw Exception(
            'Video file does not exist: $videoPath');
      }

      print('✅ Video file validation successful');
      print('📂 File path: $videoPath');
      print(
          '📊 File size: ${videoFile.lengthSync()} bytes');
      uploadStatus.value = 'Video ready for upload';
    } catch (e) {
      print('❌ Video file validation failed: $e');
      uploadStatus.value = 'Video file error';
    }
  }

  /// Upload the processed video with burned-in edits (OPTIMIZED)
  Future<bool> uploadVideo() async {
    if (isUploading.value) {
      print('⚠️ Upload already in progress');
      return false;
    }

    PostModel? uploadResult; // Declare at function scope

    try {
      isUploading.value = true;
      uploadProgress.value = 0.0;
      uploadStatus.value = 'Starting upload...';

      print(
          '🚀 Starting optimized video upload process...');
      print('📁 Video path: $videoPath');
      print('📝 Caption: ${captionController.text.trim()}');
      print('🎯 Upload type: $createType');

      // Step 1: Quick validation (10%)
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found: $videoPath');
      }

      print('✅ Video file validated successfully');

      uploadProgress.value = 20.0;
      uploadStatus.value = 'Uploading video file...';

      print('📤 Starting video file upload...');

      // Step 2: Upload video file to server (50%)
      final videoXFile = XFile(videoPath);
      FilePathModel uploadedVideo = await CommonService
          .instance
          .uploadFileGivePath(videoXFile);

      print(
          '📤 Video upload response: ${uploadedVideo.status}');
      print(
          '📤 Video upload message: ${uploadedVideo.message}');
      print('📤 Video upload data: ${uploadedVideo.data}');

      if (uploadedVideo.status == false) {
        throw Exception(
            'Video upload failed: ${uploadedVideo.message}');
      }

      uploadProgress.value = 60.0;
      uploadStatus.value = 'Generating thumbnail...';

      print('🖼️ Starting thumbnail upload...');

      // Step 3: Generate and upload thumbnail (70%)
      // Using video as thumbnail for now - optimize later if needed
      String thumbnailPath = videoPath;
      final thumbnailXFile = XFile(thumbnailPath);
      FilePathModel uploadedThumb = await CommonService
          .instance
          .uploadFileGivePath(thumbnailXFile);

      print(
          '🖼️ Thumbnail upload response: ${uploadedThumb.status}');
      print(
          '🖼️ Thumbnail upload message: ${uploadedThumb.message}');
      print(
          '🖼️ Thumbnail upload data: ${uploadedThumb.data}');

      if (uploadedThumb.status == false) {
        throw Exception(
            'Thumbnail upload failed: ${uploadedThumb.message}');
      }

      uploadProgress.value = 80.0;
      uploadStatus.value = 'Creating post...';

      // Step 4: Prepare upload parameters with uploaded file URLs
      Map<String, dynamic> uploadParams = {
        // Only add description if not empty (like working controller)
        if (captionController.text.trim().isNotEmpty)
          Params.description: captionController.text.trim(),
        Params.video: uploadedVideo.data, // Server file URL
        Params.thumbnail:
            uploadedThumb.data, // Server thumbnail URL
        Params.canComment: canComment.value
            ? 1
            : 0, // 🔧 FIX: Add missing can_comment field
        if (mentionedUserIds.isNotEmpty)
          Params.mentionedUserIds: mentionedUserIds.join(','),
      };

      // 🔍 DEBUG: Print exact parameters being sent
      print('🔧 DEBUG: Upload parameters being sent:');
      uploadParams.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });

      // 🔍 EXTRA DEBUG: Verify canComment value explicitly
      print(
          '🔧 DEBUG: canComment.value = ${canComment.value}');
      print(
          '🔧 DEBUG: canComment converted = ${canComment.value ? 1 : 0}');
      print(
          '🔧 DEBUG: Params.canComment constant = "${Params.canComment}"');

      // 🔍 COMPARISON: Let's also debug what's in the map with the exact key
      print(
          '🔧 DEBUG: Map contains "${Params.canComment}": ${uploadParams.containsKey(Params.canComment)}');
      print(
          '🔧 DEBUG: Map contains "can_comment": ${uploadParams.containsKey("can_comment")}');

      uploadProgress.value = 90.0;

      // Step 5: Create post using existing upload service
      print('🔗 About to call API service...');
      print('🔗 CreateType: $createType');
      print('🔗 Parameters ready, calling API...');

      if (createType == CreateFeedType.feed) {
        // Upload as feed video
        uploadStatus.value = 'Creating feed video post...';
        print(
            '🔗 Calling AddPostStoryService.addPostFeedVideo...');
        uploadResult = await AddPostStoryService.instance
            .addPostFeedVideo(param: uploadParams);
      } else {
        // Upload as reel video
        uploadStatus.value = 'Creating reel post...';
        print(
            '🔗 Calling AddPostStoryService.addPostReel...');
        uploadResult = await AddPostStoryService.instance
            .addPostReel(param: uploadParams);
      }

      print('🔗 API call completed');
      print(
          '🔗 Upload result status: ${uploadResult.status}');
      print(
          '🔗 Upload result message: ${uploadResult.message}');

      uploadProgress.value = 90.0;
      uploadStatus.value = 'Finalizing upload...';

      // Step 5: Check upload result
      if (uploadResult.status == true) {
        uploadProgress.value = 100.0;
        uploadStatus.value =
            'Upload completed successfully!';

        print('✅ Video upload successful');
        print('📋 Post ID: ${uploadResult.data?.id}');

        // 🎉 Show success message to user
        _showSuccessMessage();

        // Call success callback - this will handle navigation
        if (onAddPost != null) {
          print(
              '🔄 Calling onAddPost callback for navigation...');
          onAddPost!(
            post: uploadResult.data,
            type: createType,
          );
        } else {
          // Fallback navigation only if no callback provided
          print(
              '⚠️ No onAddPost callback provided, using fallback navigation');
          _navigateToCorrectDestination(
              uploadResult.data, createType);
        }

        return true;
      } else {
        throw Exception(
            'Upload failed: ${uploadResult.message ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ Video upload failed: $e');

      // Handle device-specific provider errors
      String errorMessage = e.toString();
      if (errorMessage
              .contains('oplus.statistics.provider') ||
          errorMessage.contains('OplusStatistics') ||
          errorMessage.contains('provider info')) {
        errorMessage =
            'Upload completed but analytics failed. This is safe to ignore.';
        print(
            '⚠️ OnePlus provider error detected - treating as warning');

        // For provider errors, we might still want to show success if the main upload worked
        // Check if uploadResult indicates success despite the provider error
        if (uploadResult != null &&
            uploadResult.status == true) {
          uploadStatus.value =
              'Upload completed with analytics warning';
          _showSuccessMessage();

          // Call success callback - this will handle navigation
          if (onAddPost != null) {
            print(
                '🔄 Calling onAddPost callback for navigation (despite provider warning)...');
            onAddPost!(
              post: uploadResult.data,
              type: createType,
            );
          } else {
            // Fallback navigation only if no callback provided
            print(
                '⚠️ No onAddPost callback provided, using fallback navigation');
            _navigateToCorrectDestination(
                uploadResult.data, createType);
          }
          return true;
        }
      }

      uploadStatus.value = 'Upload failed: ${errorMessage}';
      uploadProgress.value = 0.0;

      // Show error message
      Get.snackbar(
        'Upload Failed',
        errorMessage,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      return false;
    } finally {
      isUploading.value = false;
    }
  }

  /// 🎉 Show success message for video upload
  void _showSuccessMessage() {
    String message;
    Color backgroundColor;
    IconData icon;

    if (createType == CreateFeedType.reel) {
      message = '🎬 Reel uploaded successfully!';
      backgroundColor =
          Colors.purple.withValues(alpha: 0.9);
      icon = Icons.video_library_rounded;
    } else {
      message = '🎥 Video uploaded successfully!';
      backgroundColor = Colors.blue.withValues(alpha: 0.9);
      icon = Icons.video_library_rounded;
    }

    Get.snackbar(
      '✅ Upload Complete',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: backgroundColor,
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      animationDuration: const Duration(milliseconds: 500),
    );

    print('User notified: $message');
  }

  /// Alternative method: Navigate to existing CreateFeedScreen
  /// This can be used as a fallback or alternative approach
  void navigateToCreateFeedScreen() {
    try {
      print('🔄 Fallback: Navigating to CreateFeedScreen');

      final content = PostStoryContent(
        type: PostStoryContentType.storyVideo,
        content: videoPath,
        hasAudio: false,
      );

      Get.off(() => CreateFeedScreen(
            createType: createType,
            content: content,
            onAddPost: onAddPost,
          ));
    } catch (e) {
      print('❌ Error navigating to CreateFeedScreen: $e');
      Get.snackbar(
        'Navigation Error',
        'Failed to open upload screen: ${e.toString()}',
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  /// Navigate to appropriate destination based on content type
  /// This is a fallback method - proper navigation should be handled by onAddPost callbacks
  void _navigateToCorrectDestination(
      Post? post, CreateFeedType createType) {
    if (post == null) return;

    print('🧭 Fallback navigation for ${createType.name}');
    print(
        '⚠️ Note: This should normally be handled by onAddPost callback');

    // Just close the current upload screen and let dashboard handle the rest
    Future.delayed(const Duration(milliseconds: 500), () {
      Get.back();

      // Optional: Try to navigate to appropriate section as fallback
      if (Get.isRegistered<DashboardScreenController>()) {
        final dashboardController =
            Get.find<DashboardScreenController>();

        switch (createType) {
          case CreateFeedType.feed:
            // Navigate to feed tab
            dashboardController.onBottomIndexChanged
                ?.call(0);
            print('📰 Fallback: Navigated to Feed tab');

            // Show success message
            Future.delayed(
                const Duration(milliseconds: 500), () {
              Get.snackbar(
                '📰 Feed Upload Complete',
                'Your video is now in the Feed tab!',
                snackPosition: SnackPosition.TOP,
                backgroundColor:
                    Colors.blue.withOpacity(0.9),
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
                margin: const EdgeInsets.all(16),
              );
            });
            break;

          case CreateFeedType.reel:
            // Navigate to profile and show reels tab
            dashboardController.onBottomIndexChanged
                ?.call(4); // Profile tab

            // Switch to reels tab in profile
            Future.delayed(
                const Duration(milliseconds: 300), () {
              if (Get.isRegistered<ProfileScreenController>(
                  tag: ProfileScreenController.tag)) {
                final profileController =
                    Get.find<ProfileScreenController>(
                        tag: ProfileScreenController.tag);
                profileController.selectedTabIndex.value =
                    0; // Reels tab (index 0)
                print(
                    '🎬 Fallback: Navigated to Profile Reels tab');

                // Show success message
                Future.delayed(
                    const Duration(milliseconds: 200), () {
                  Get.snackbar(
                    '🎬 Reel Upload Complete',
                    'Your reel is now in your Profile Reels tab!',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor:
                        Colors.red.withOpacity(0.9),
                    colorText: Colors.white,
                    duration: const Duration(seconds: 3),
                    margin: const EdgeInsets.all(16),
                  );
                });
              }
            });
            break;
        }
      }
    });
  }

  @override
  void onClose() {
    captionController.dispose();
    super.onClose();
  }
}
