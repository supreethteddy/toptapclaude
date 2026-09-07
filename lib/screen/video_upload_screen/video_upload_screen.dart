import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:detectable_text_field/detectable_text_field.dart';
import 'package:shortzz/common/widget/loader_widget.dart';
import 'package:shortzz/common/widget/user_list.dart';
import 'package:shortzz/languages/languages_keys.dart';
import 'package:shortzz/model/user_model/user_model.dart';
import 'package:shortzz/model/post_story/post_model.dart';
import 'package:shortzz/screen/create_feed_screen/create_feed_screen.dart';
import 'package:shortzz/screen/create_feed_screen/create_feed_screen_controller.dart';
import 'package:shortzz/screen/video_upload_screen/video_upload_controller.dart';

/// 🎬 VideoUploadScreen - Dedicated screen for uploading processed videos with edits
/// This screen is specifically designed for videos that have text, stickers, and drawings
/// already burned into the video file. It provides a video-specific upload interface.
class VideoUploadScreen extends StatefulWidget {
  final String
      videoPath; // Path to processed video with edits burned in
  final CreateFeedType createType; // Feed or Reel type
  final Function({Post? post, CreateFeedType? type})?
      onAddPost; // Success callback

  const VideoUploadScreen({
    Key? key,
    required this.videoPath,
    required this.createType,
    this.onAddPost,
  }) : super(key: key);

  @override
  State<VideoUploadScreen> createState() =>
      _VideoUploadScreenState();
}

class _VideoUploadScreenState
    extends State<VideoUploadScreen> {
  late VideoUploadController controller;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
    _initializeVideoPlayer();
  }

  void _initializeController() {
    try {
      print(
          '🎬 Initializing VideoUploadScreen with processed video: ${widget.videoPath}');
      print(
          '📂 Video file exists: ${File(widget.videoPath).existsSync()}');
      print('🎯 Upload type: ${widget.createType}');

      // Initialize the video upload controller
      controller = Get.put(VideoUploadController(
        videoPath: widget.videoPath,
        createType: widget.createType,
        onAddPost: widget.onAddPost,
      ));

      print(
          '✅ VideoUploadController initialized successfully');
    } catch (e) {
      print(
          '❌ Error initializing VideoUploadController: $e');
      _showErrorMessage(
          'Failed to initialize upload screen: ${e.toString()}');
    }
  }

  void _initializeVideoPlayer() async {
    try {
      print(
          '🎥 Initializing video player for: ${widget.videoPath}');

      final videoFile = File(widget.videoPath);
      if (!videoFile.existsSync()) {
        throw Exception(
            'Video file does not exist: ${widget.videoPath}');
      }

      _videoPlayerController =
          VideoPlayerController.file(videoFile);
      await _videoPlayerController!.initialize();

      setState(() {
        _isVideoInitialized = true;
      });

      print('✅ Video player initialized successfully');
      print(
          '📹 Video duration: ${_videoPlayerController!.value.duration}');
      print(
          '📐 Video size: ${_videoPlayerController!.value.size}');
    } catch (e) {
      print('❌ Error initializing video player: $e');
      _showErrorMessage(
          'Failed to load video preview: ${e.toString()}');
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Colors.white),
          onPressed: () {
            final navigator = Navigator.maybeOf(context);
            if (navigator != null && navigator.canPop()) {
              navigator.maybePop();
              return;
            }
            if (Get.key.currentState?.canPop() ?? false) {
              Get.back();
            }
          },
        ),
        title: Text(
          'Upload ${widget.createType == CreateFeedType.feed ? 'Video Post' : 'Video Reel'}',
          style: const TextStyle(
              color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Video Preview Section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildVideoPreview(),
              ),
            ),

            // Upload Controls Section
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: _buildUploadControls(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video Player or Loading
          if (_isVideoInitialized &&
              _videoPlayerController != null)
            AspectRatio(
              aspectRatio:
                  _videoPlayerController!.value.aspectRatio,
              child: VideoPlayer(_videoPlayerController!),
            )
          else
            Container(
              color: Colors.grey[800],
              child: const Center(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                        color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading video preview...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Play/Pause Button
          if (_isVideoInitialized)
            Positioned(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_videoPlayerController!
                        .value.isPlaying) {
                      _videoPlayerController!.pause();
                    } else {
                      _videoPlayerController!.play();
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    _videoPlayerController!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),

          // Processing Status Indicator
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Edits burned into video',
                    style: TextStyle(
                        color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadControls() {
    return GetBuilder<VideoUploadController>(
      builder: (controller) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caption Input
            const Text(
              'Add a caption',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DetectableTextField(
              controller: controller.commentHelper.detectableTextController,
              focusNode: controller.commentHelper.detectableTextFocusNode,
              onChanged: controller.commentHelper.onChanged,
              keyboardType: TextInputType.twitter,
              textInputAction: TextInputAction.newline,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.createType ==
                        CreateFeedType.feed
                    ? 'Write a caption for your video post...'
                    : 'Write a caption for your video reel... (optional)',
                hintStyle:
                    TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey[600]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            _buildMentionSuggestions(),

            const SizedBox(height: 16),

            // Video Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.videocam,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Video ready for upload',
                        style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14),
                      ),
                    ],
                  ),
                  if (_isVideoInitialized &&
                      _videoPlayerController != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Colors.grey, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Duration: ${_formatDuration(_videoPlayerController!.value.duration)}',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // Upload Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Obx(() => ElevatedButton(
                    onPressed: controller.isUploading.value
                        ? null
                        : () => _handleUpload(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor:
                          Colors.grey[700],
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                    ),
                    child: controller.isUploading.value
                        ? Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<
                                              Color>(
                                          Colors.white),
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Uploading ${controller.uploadProgress.value.toInt()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16),
                              ),
                            ],
                          )
                        : Text(
                            'Upload ${widget.createType == CreateFeedType.feed ? 'Video Post' : 'Video Reel'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  )),
            ),
          ],
        );
      },
    );
  }

  /// User suggestions shown while typing "@name" in the caption.
  Widget _buildMentionSuggestions() {
    final helper = controller.commentHelper;
    return Obx(() {
      if (!helper.isMentionUserView.value) return const SizedBox.shrink();
      final List<User> users = helper.searchUsers;
      return Container(
        margin: const EdgeInsets.only(top: 6),
        constraints: const BoxConstraints(maxHeight: 170),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: helper.isLoading.value
            ? const SizedBox(height: 60, child: LoaderWidget())
            : users.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(LKey.mentionSomeone.tr,
                        style: TextStyle(color: Colors.grey[400])),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return UserCard(
                        onTap: () => helper.appendDetection(
                            user, DetectType.atSign,
                            type: 1),
                        fullName: user.fullname,
                        profilePhoto: user.profilePhoto,
                        userName: user.username,
                        isVerified: user.isVerify ?? 0,
                      );
                    },
                  ),
      );
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes =
        twoDigits(duration.inMinutes.remainder(60));
    final seconds =
        twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _handleUpload() async {
    // Validate caption for feed posts (reels can be uploaded without caption)
    if (widget.createType == CreateFeedType.feed &&
        controller.captionController.text.trim().isEmpty) {
      _showErrorMessage(
          'Please add a caption for your video post');
      return;
    }

    try {
      print('🚀 Starting video upload process...');
      print(
          '📝 Caption: ${controller.captionController.text.trim()}');
      print('🎯 Upload type: ${widget.createType}');

      final success = await controller.uploadVideo();

      if (success) {
        _showSuccessMessage('Video uploaded successfully!');

        // Call success callback
        if (widget.onAddPost != null) {
          widget.onAddPost!(
            post:
                null, // Post object would be available from controller if needed
            type: widget.createType,
          );
        }
      } else {
        _showErrorMessage(
            'Failed to upload video. Please try again.');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      _showErrorMessage('Upload failed: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }
}
