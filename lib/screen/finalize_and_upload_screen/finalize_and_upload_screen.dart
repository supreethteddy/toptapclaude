// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:toptap/model/post_story/post_model.dart';
// import 'package:toptap/screen/camera_screen/camera_types.dart';
// import 'package:toptap/screen/create_feed_screen/create_feed_screen.dart';

// /// 🎬 FinalizeAndUploadScreen - Screen for finalizing and uploading processed videos
// /// This screen receives videos with edits already burned in and provides
// /// a simple interface that navigates to the existing CreateFeedScreen.
// class FinalizeAndUploadScreen extends StatefulWidget {
//   final String
//       videoPath; // Path to processed video with edits burned in
//   final CreateFeedType createType; // Feed or Reel type
//   final Function({Post? post, CreateFeedType? type})?
//       onAddPost; // Success callback

//   const FinalizeAndUploadScreen({
//     Key? key,
//     required this.videoPath,
//     required this.createType,
//     this.onAddPost,
//   }) : super(key: key);

//   @override
//   State<FinalizeAndUploadScreen> createState() =>
//       _FinalizeAndUploadScreenState();
// }

// class _FinalizeAndUploadScreenState
//     extends State<FinalizeAndUploadScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Navigate to CreateFeedScreen immediately with processed video
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _navigateToCreateFeedScreen();
//     });
//   }

//   void _navigateToCreateFeedScreen() {
//     try {
//       print(
//           '🎬 FinalizeAndUploadScreen: Navigating to CreateFeedScreen');
//       print('📂 Video path: ${widget.videoPath}');
//       print(
//           '📂 Video exists: ${File(widget.videoPath).existsSync()}');
//       print('🎯 Create type: ${widget.createType}');

//       // Create content from processed video
//       final content = PostStoryContent(
//         type: PostStoryContentType.storyVideo,
//         content: widget
//             .videoPath, // Video with edits already burned in
//         hasAudio: false,
//       );

//       // Navigate to CreateFeedScreen with processed content
//       Get.off(() => CreateFeedScreen(
//             createType: widget.createType,
//             content: content,
//             // No videoEditingController needed - edits are burned into video
//             onAddPost: widget.onAddPost,
//           ));

//       print('✅ Successfully navigated to CreateFeedScreen');
//     } catch (e) {
//       print('❌ Error navigating to CreateFeedScreen: $e');
//       _showErrorMessage(
//           'Failed to open upload screen: ${e.toString()}');
//     }
//   }

//   void _showErrorMessage(String message) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text(message),
//             backgroundColor: Colors.red),
//       );
//       // Go back on error
//       Get.back();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Show loading while transitioning
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: const Center(
//         child: CircularProgressIndicator(
//           valueColor:
//               AlwaysStoppedAnimation<Color>(Colors.blue),
//         ),
//       ),
//     );
//   }
// }
