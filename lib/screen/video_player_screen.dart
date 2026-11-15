// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:video_player/video_player.dart';
// import 'package:toptap/screen/create_feed_screen/create_feed_screen.dart';
// import 'package:toptap/screen/camera_screen/camera_types.dart';
// import 'package:toptap/model/post_story/post_model.dart';

// class VideoPlayerScreen extends StatefulWidget {
//   final String videoPath;

//   const VideoPlayerScreen({
//     Key? key,
//     required this.videoPath,
//   }) : super(key: key);

//   @override
//   State<VideoPlayerScreen> createState() =>
//       _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState
//     extends State<VideoPlayerScreen> {
//   VideoPlayerController? _controller;
//   bool _isLoading = true;
//   bool _hasError = false;
//   bool _showControls = true;
//   String _errorMessage = '';

//   @override
//   void initState() {
//     super.initState();
//     _initializeVideoPlayer();

//     // Hide system UI for full-screen experience
//     SystemChrome.setEnabledSystemUIMode(
//         SystemUiMode.immersiveSticky);
//   }

//   Future<void> _initializeVideoPlayer() async {
//     try {
//       print(
//           '🎥 Initializing video player for: ${widget.videoPath}');

//       // Check if file exists
//       final videoFile = File(widget.videoPath);
//       if (!await videoFile.exists()) {
//         setState(() {
//           _hasError = true;
//           _errorMessage = 'Video file not found';
//           _isLoading = false;
//         });
//         return;
//       }

//       // Check file size
//       final fileSize = await videoFile.length();
//       print('📱 Video file size: $fileSize bytes');

//       if (fileSize < 100) {
//         setState(() {
//           _hasError = true;
//           _errorMessage =
//               'Video file is too small ($fileSize bytes) - likely a mock file';
//           _isLoading = false;
//         });
//         print('❌ Video file too small: $fileSize bytes');
//         return;
//       }

//       // Initialize video player controller
//       _controller = VideoPlayerController.file(videoFile);

//       await _controller!.initialize();

//       // Set video to repeat
//       await _controller!.setLooping(true);

//       // Start playing automatically
//       await _controller!.play();

//       print('✅ Video player initialized successfully');
//       print(
//           '📐 Video dimensions: ${_controller!.value.size.width}x${_controller!.value.size.height}');
//       print(
//           '⏱️ Video duration: ${_controller!.value.duration.inSeconds}s');

//       setState(() {
//         _isLoading = false;
//         _hasError = false;
//       });

//       // Hide controls after 3 seconds
//       Future.delayed(const Duration(seconds: 3), () {
//         if (mounted) {
//           setState(() {
//             _showControls = false;
//           });
//         }
//       });
//     } catch (e) {
//       print('❌ Error initializing video player: $e');
//       setState(() {
//         _hasError = true;
//         _errorMessage =
//             'Failed to load video: ${e.toString()}';
//         _isLoading = false;
//       });
//     }
//   }

//   void _togglePlayPause() {
//     if (_controller == null) return;

//     setState(() {
//       if (_controller!.value.isPlaying) {
//         _controller!.pause();
//       } else {
//         _controller!.play();
//       }
//     });
//   }

//   void _toggleControls() {
//     setState(() {
//       _showControls = !_showControls;
//     });
//   }

//   void _exitPlayer() {
//     // Restore system UI
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
//         overlays: [
//           SystemUiOverlay.top,
//           SystemUiOverlay.bottom,
//         ]);

//     Get.back();
//   }

//   @override
//   void dispose() {
//     _controller?.dispose();

//     // Restore system UI
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
//         overlays: [
//           SystemUiOverlay.top,
//           SystemUiOverlay.bottom,
//         ]);

//     super.dispose();
//   }

//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final minutes =
//         twoDigits(duration.inMinutes.remainder(60));
//     final seconds =
//         twoDigits(duration.inSeconds.remainder(60));
//     return '$minutes:$seconds';
//   }

//   // Show sound picker options
//   void _showSoundOptions() {
//     print('🎵 Opening sound picker...');
//     Get.bottomSheet(
//       Container(
//         height: 300,
//         decoration: const BoxDecoration(
//           color: Colors.black87,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(20),
//             topRight: Radius.circular(20),
//           ),
//         ),
//         child: Column(
//           children: [
//             const Padding(
//               padding: EdgeInsets.all(16),
//               child: Text(
//                 'Add Sound',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             Expanded(
//               child: ListView(
//                 children: [
//                   ListTile(
//                     leading: const Icon(Icons.music_note,
//                         color: Colors.red),
//                     title: const Text('Original Sound',
//                         style:
//                             TextStyle(color: Colors.white)),
//                     subtitle: const Text(
//                         'Use original video audio',
//                         style: TextStyle(
//                             color: Colors.white70)),
//                     onTap: () {
//                       Get.back();
//                       Get.snackbar(
//                           'Sound', 'Original sound kept',
//                           backgroundColor: Colors.green,
//                           colorText: Colors.white);
//                     },
//                   ),
//                   ListTile(
//                     leading: const Icon(Icons.library_music,
//                         color: Colors.blue),
//                     title: const Text('Music Library',
//                         style:
//                             TextStyle(color: Colors.white)),
//                     subtitle: const Text(
//                         'Choose from music library',
//                         style: TextStyle(
//                             color: Colors.white70)),
//                     onTap: () {
//                       Get.back();
//                       Get.snackbar(
//                           'Music', 'Music library opened',
//                           backgroundColor: Colors.blue,
//                           colorText: Colors.white);
//                     },
//                   ),
//                   ListTile(
//                     leading: const Icon(Icons.mic,
//                         color: Colors.orange),
//                     title: const Text('Record Voice',
//                         style:
//                             TextStyle(color: Colors.white)),
//                     subtitle: const Text(
//                         'Add voice recording',
//                         style: TextStyle(
//                             color: Colors.white70)),
//                     onTap: () {
//                       Get.back();
//                       Get.snackbar(
//                           'Voice', 'Voice recorder opened',
//                           backgroundColor: Colors.orange,
//                           colorText: Colors.white);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showEnhancedTextEditor() {
//     print(
//         '🚀 PHOTO PREVIEW: Opening enhanced text editor...');
//     // Clear selection before creating new text
//     controller.selectedTextElementId.value = '';
//     Get.bottomSheet(
//       EnhancedTextEditorSheet(
//         onTextCreated: (textElement) {
//           // FIXED: Use addEnhancedText instead of addText to prevent duplicate text creation
//           controller.addEnhancedText(textElement);
//         },
//       ),
//       isScrollControlled: true,
//       enableDrag: true,
//     );
//   }

//   // Show add text dialog
//   // void _showAddTextDialog() {
//   //   print('📝 Opening add text dialog...');
//   //   final TextEditingController textController =
//   //       TextEditingController();

//   //   Get.dialog(
//   //     AlertDialog(
//   //       backgroundColor: Colors.black87,
//   //       title: const Text('Add Text',
//   //           style: TextStyle(color: Colors.white)),
//   //       content: Column(
//   //         mainAxisSize: MainAxisSize.min,
//   //         children: [
//   //           TextField(
//   //             controller: textController,
//   //             style: const TextStyle(color: Colors.white),
//   //             decoration: const InputDecoration(
//   //               hintText: 'Enter your text...',
//   //               hintStyle: TextStyle(color: Colors.white54),
//   //               enabledBorder: UnderlineInputBorder(
//   //                 borderSide:
//   //                     BorderSide(color: Colors.white54),
//   //               ),
//   //               focusedBorder: UnderlineInputBorder(
//   //                 borderSide: BorderSide(color: Colors.red),
//   //               ),
//   //             ),
//   //             maxLines: 3,
//   //           ),
//   //           const SizedBox(height: 20),
//   //           Row(
//   //             children: [
//   //               const Text('Color: ',
//   //                   style: TextStyle(color: Colors.white)),
//   //               Expanded(
//   //                 child: Row(
//   //                   children: [
//   //                     _buildColorOption(Colors.white),
//   //                     _buildColorOption(Colors.red),
//   //                     _buildColorOption(Colors.blue),
//   //                     _buildColorOption(Colors.green),
//   //                     _buildColorOption(Colors.yellow),
//   //                     _buildColorOption(Colors.purple),
//   //                   ],
//   //                 ),
//   //               ),
//   //             ],
//   //           ),
//   //         ],
//   //       ),
//   //       actions: [
//   //         TextButton(
//   //           onPressed: () => Get.back(),
//   //           child: const Text('Cancel',
//   //               style: TextStyle(color: Colors.white70)),
//   //         ),
//   //         TextButton(
//   //           onPressed: () {
//   //             if (textController.text.isNotEmpty) {
//   //               Get.back();
//   //               Get.snackbar(
//   //                   'Text Added', textController.text,
//   //                   backgroundColor: Colors.green,
//   //                   colorText: Colors.white);
//   //             }
//   //           },
//   //           child: const Text('Add',
//   //               style: TextStyle(color: Colors.red)),
//   //         ),
//   //       ],
//   //     ),
//   //   );
//   // }

//   Widget _buildColorOption(Color color) {
//     return GestureDetector(
//       onTap: () {
//         // Handle color selection
//         print('Color selected: $color');
//       },
//       child: Container(
//         width: 30,
//         height: 30,
//         margin: const EdgeInsets.symmetric(horizontal: 4),
//         decoration: BoxDecoration(
//           color: color,
//           shape: BoxShape.circle,
//           border:
//               Border.all(color: Colors.white54, width: 1),
//         ),
//       ),
//     );
//   }

//   // Navigate to Create Feed screen
//   void _navigateToCreateFeed() {
//     print(
//         '📱 Navigating to Create Feed screen with video: ${widget.videoPath}');

//     if (widget.videoPath.isEmpty) {
//       Get.snackbar('Error', 'No video to share',
//           backgroundColor: Colors.red.withOpacity(0.8),
//           colorText: Colors.white);
//       return;
//     }

//     // Create PostStoryContent with the captured video
//     final content = PostStoryContent(
//       type: PostStoryContentType.storyVideo,
//       content: widget.videoPath,
//       hasAudio: true, // Assume video has audio
//     );

//     // Navigate to Create Feed Screen
//     Get.to(() => CreateFeedScreen(
//           createType: CreateFeedType.feed,
//           content: content,
//           onAddPost: ({Post? post, CreateFeedType? type}) {
//             // Navigate back to main app after posting
//             Get.until((route) => route.isFirst);
//           },
//         ));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: GestureDetector(
//         onTap: _toggleControls,
//         child: Stack(
//           children: [
//             // Video player or loading/error state
//             Center(
//               child: _buildVideoContent(),
//             ),

//             // Controls overlay
//             if (_showControls) _buildControlsOverlay(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildVideoContent() {
//     if (_isLoading) {
//       return const Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(color: Colors.white),
//           SizedBox(height: 20),
//           Text(
//             'Loading video...',
//             style: TextStyle(
//                 color: Colors.white, fontSize: 16),
//           ),
//         ],
//       );
//     }

//     if (_hasError) {
//       return Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(
//             Icons.error_outline,
//             color: Colors.red,
//             size: 80,
//           ),
//           const SizedBox(height: 20),
//           const Text(
//             'Video Playback Error',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 10),
//           Padding(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 40),
//             child: Text(
//               _errorMessage,
//               style: const TextStyle(
//                 color: Colors.white70,
//                 fontSize: 14,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           const SizedBox(height: 30),
//           ElevatedButton.icon(
//             onPressed: _exitPlayer,
//             icon: const Icon(Icons.arrow_back,
//                 color: Colors.white),
//             label: const Text('Go Back',
//                 style: TextStyle(color: Colors.white)),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               padding: const EdgeInsets.symmetric(
//                   horizontal: 20, vertical: 12),
//             ),
//           ),
//         ],
//       );
//     }

//     // Video player with proper orientation handling
//     return Container(
//       width: double.infinity,
//       height: double.infinity,
//       color: Colors.black,
//       child: Center(
//         child: _controller != null
//             ? AspectRatio(
//                 aspectRatio: _controller!.value.aspectRatio,
//                 child: VideoPlayer(_controller!),
//               )
//             : const CircularProgressIndicator(),
//       ),
//     );
//   }

//   Widget _buildControlsOverlay() {
//     return Container(
//       width: double.infinity,
//       height: double.infinity,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [
//             Colors.black.withOpacity(0.7),
//             Colors.transparent,
//             Colors.transparent,
//             Colors.black.withOpacity(0.7),
//           ],
//         ),
//       ),
//       child: Stack(
//         children: [
//           // Top controls - Navigation bar like photo preview
//           Positioned(
//             top: MediaQuery.of(context).padding.top + 10,
//             left: 20,
//             right: 20,
//             child: Row(
//               mainAxisAlignment:
//                   MainAxisAlignment.spaceBetween,
//               children: [
//                 // Left: Close button
//                 GestureDetector(
//                   onTap: _exitPlayer,
//                   child: Container(
//                     width: 48,
//                     height: 48,
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.7),
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(
//                       Icons.close,
//                       color: Colors.white,
//                       size: 24,
//                     ),
//                   ),
//                 ),

//                 // Middle: Add Sound option
//                 GestureDetector(
//                   onTap: _showSoundOptions,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.7),
//                       borderRadius:
//                           BorderRadius.circular(20),
//                     ),
//                     child: const Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(Icons.music_note,
//                             color: Colors.red, size: 18),
//                         SizedBox(width: 6),
//                         Text(
//                           'Add Sound',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),

//                 // Right: Next button
//                 GestureDetector(
//                   onTap: _navigateToCreateFeed,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 20, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: Colors.red,
//                       borderRadius:
//                           BorderRadius.circular(20),
//                     ),
//                     child: const Text(
//                       'Next',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Center play/pause button
//           Center(
//             child: GestureDetector(
//               onTap: _togglePlayPause,
//               child: Container(
//                 width: 80,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.7),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   _controller?.value.isPlaying == true
//                       ? Icons.pause
//                       : Icons.play_arrow,
//                   color: Colors.white,
//                   size: 40,
//                 ),
//               ),
//             ),
//           ),

//           // Right side: Add Text option
//           Positioned(
//             right: 20,
//             top: MediaQuery.of(context).size.height * 0.4,
//             child: GestureDetector(
//               onTap: _showEnhancedTextEditor,
//               child: Container(
//                 width: 60,
//                 height: 60,
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.7),
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: Colors.white.withOpacity(0.2),
//                     width: 1,
//                   ),
//                 ),
//                 child: const Column(
//                   mainAxisAlignment:
//                       MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.text_fields,
//                         color: Colors.white, size: 22),
//                     SizedBox(height: 2),
//                     Text(
//                       'Text',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 10,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // Bottom controls - Progress bar and video info
//           Positioned(
//             bottom:
//                 MediaQuery.of(context).padding.bottom + 20,
//             left: 20,
//             right: 20,
//             child: Column(
//               children: [
//                 // Video info
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         widget.videoPath.split('/').last,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 10),

//                 // Progress bar
//                 if (_controller != null)
//                   VideoProgressIndicator(
//                     _controller!,
//                     allowScrubbing: true,
//                     colors: const VideoProgressColors(
//                       playedColor: Colors.red,
//                       bufferedColor: Colors.white30,
//                       backgroundColor: Colors.white12,
//                     ),
//                   ),
//                 const SizedBox(height: 10),

//                 // Time display
//                 Row(
//                   mainAxisAlignment:
//                       MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       _formatDuration(
//                           _controller?.value.position ??
//                               Duration.zero),
//                       style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 12),
//                     ),
//                     Text(
//                       _formatDuration(
//                           _controller?.value.duration ??
//                               Duration.zero),
//                       style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
