// Shared types for camera functionality
// This file contains types that are used across the app

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toptap/screen/selected_music_sheet/selected_music_sheet_controller.dart';

// Camera screen types
enum CameraScreenType { post, story }

// Post story content types
enum PostStoryContentType {
  reel,
  storyText,
  storyImage,
  storyVideo
}

// Default filter constant - Identity matrix for ColorFilter.matrix (4x5 = 20 values)
const List<double> defaultFilter = [
  1, 0, 0, 0, 0, // Red
  0, 1, 0, 0, 0, // Green
  0, 0, 1, 0, 0, // Blue
  0, 0, 0, 1, 0 // Alpha
];

// Post story content model
class PostStoryContent {
  final PostStoryContentType type;
  String? content;
  String? thumbNail;
  int? duration;
  List<double> filter;
  bool hasAudio;
  SelectedMusic? sound;
  LinearGradient? bgGradient;
  Uint8List? thumbnailBytes;

  PostStoryContent({
    required this.type,
    this.content,
    this.thumbNail,
    this.duration,
    this.filter = defaultFilter,
    this.sound,
    this.bgGradient,
    this.thumbnailBytes,
    this.hasAudio = true,
  });
}
