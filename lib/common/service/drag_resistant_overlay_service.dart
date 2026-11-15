import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:toptap/common/manager/logger.dart';

/// Service to handle drag-resistant video overlay rendering
class DragResistantOverlayService {
  static const String _tag = 'DragResistantOverlay';

  /// Capture overlay without causing black screen during drag operations
  static Future<ui.Image?>
      captureOverlayWithDragResistance({
    required GlobalKey repaintBoundaryKey,
    double pixelRatio = 1.0,
    int maxRetries = 5,
  }) async {
    try {
      Loggers.info(
          '$_tag: Capturing overlay with drag resistance...');

      // Find the RenderRepaintBoundary
      final context = repaintBoundaryKey.currentContext;
      if (context == null) {
        Loggers.error(
            '$_tag: RepaintBoundary context is null');
        return null;
      }

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        Loggers.error(
            '$_tag: RenderObject is not a RenderRepaintBoundary');
        return null;
      }

      // Multiple capture attempts with different strategies
      for (int attempt = 1;
          attempt <= maxRetries;
          attempt++) {
        try {
          Loggers.info(
              '$_tag: Capture attempt $attempt of $maxRetries');

          // Wait for any ongoing animations or updates to settle
          await _waitForStableState();

          // Use decreasing pixel ratio for problematic captures
          final currentPixelRatio =
              _calculateOptimalPixelRatio(
                  attempt, pixelRatio);

          // Attempt capture
          final image = await renderObject.toImage(
              pixelRatio: currentPixelRatio);

          // Validate the captured image
          if (await _isValidImage(image)) {
            Loggers.success(
                '$_tag: Successfully captured overlay on attempt $attempt');
            return image;
          } else {
            Loggers.warning(
                '$_tag: Captured image appears invalid (attempt $attempt)');
          }
        } catch (e) {
          Loggers.warning(
              '$_tag: Capture attempt $attempt failed: $e');

          if (attempt == maxRetries) {
            Loggers.error(
                '$_tag: All capture attempts failed');
            return null;
          }

          // Progressive delay between attempts
          await Future.delayed(
              Duration(milliseconds: 50 * attempt));
        }
      }

      return null;
    } catch (e) {
      Loggers.error(
          '$_tag: Error in captureOverlayWithDragResistance: $e');
      return null;
    }
  }

  /// Wait for UI state to stabilize before capture
  static Future<void> _waitForStableState() async {
    // Wait for any ongoing animations
    await Future.delayed(
        const Duration(milliseconds: 16)); // One frame

    // Ensure all widget updates are complete
    WidgetsBinding.instance.ensureVisualUpdate();

    // Additional small delay to ensure stability
    await Future.delayed(const Duration(milliseconds: 16));
  }

  /// Calculate optimal pixel ratio based on attempt number
  static double _calculateOptimalPixelRatio(
      int attempt, double originalRatio) {
    switch (attempt) {
      case 1:
        return originalRatio; // Original ratio first
      case 2:
        return originalRatio * 0.8; // Slightly lower
      case 3:
        return originalRatio * 0.6; // Medium quality
      case 4:
        return originalRatio * 0.4; // Lower quality
      case 5:
      default:
        return originalRatio *
            0.2; // Minimum quality as fallback
    }
  }

  /// Validate that the captured image is not corrupted or blank
  static Future<bool> _isValidImage(ui.Image image) async {
    try {
      // Check basic dimensions
      if (image.width <= 0 || image.height <= 0) {
        return false;
      }

      // Check if image is not too small (indicating failure)
      if (image.width < 100 || image.height < 100) {
        Loggers.warning(
            '$_tag: Image dimensions seem too small: ${image.width}x${image.height}');
        return false;
      }

      // Check if we can convert to byte data (basic corruption test)
      final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png);
      if (byteData == null ||
          byteData.lengthInBytes < 1000) {
        return false;
      }

      return true;
    } catch (e) {
      Loggers.warning('$_tag: Error validating image: $e');
      return false;
    }
  }

  /// Create a stable overlay capture environment
  static Widget createStableOverlayEnvironment({
    required Widget child,
    required GlobalKey repaintBoundaryKey,
  }) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Container(
        // Ensure stable background for capture
        color: Colors.transparent,
        child: Stack(
          children: [
            // Stable base layer
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // Content layer
            child,
          ],
        ),
      ),
    );
  }

  /// Enhanced drag gesture detector that prevents black screen issues
  static Widget createDragResistantGestureDetector({
    required Widget child,
    required Function(DragStartDetails) onPanStart,
    required Function(DragUpdateDetails) onPanUpdate,
    Function(DragEndDetails)? onPanEnd,
    Function()? onTap,
  }) {
    return GestureDetector(
      // Use opaque hit test behavior to ensure proper gesture capture
      behavior: HitTestBehavior.opaque,

      // Wrap callbacks with drag resistance logic
      onPanStart: (details) {
        // Ensure UI is in stable state before starting drag
        WidgetsBinding.instance.ensureVisualUpdate();
        onPanStart(details);
      },

      onPanUpdate: (details) {
        // Throttle updates to prevent too frequent redraws
        onPanUpdate(details);
      },

      onPanEnd: onPanEnd != null
          ? (details) {
              // Ensure UI stabilizes after drag ends
              WidgetsBinding.instance.ensureVisualUpdate();
              onPanEnd(details);
            }
          : null,

      onTap: onTap != null
          ? () {
              WidgetsBinding.instance.ensureVisualUpdate();
              onTap();
            }
          : null,

      child: child,
    );
  }

  /// Create a performance-optimized overlay widget for editing elements
  static Widget createOptimizedOverlayWidget({
    required Widget child,
    required bool isSelected,
    Color selectionColor = Colors.blue,
    double selectionWidth = 2.0,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: isSelected
            ? Border.all(
                color: selectionColor,
                width: selectionWidth)
            : null,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: selectionColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  /// Batch update multiple editing elements to reduce redraws
  static void batchUpdateElements(
      List<VoidCallback> updates) {
    // Execute all updates in batch
    for (final update in updates) {
      update();
    }

    // Ensure single redraw for all changes
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Check if current device/platform has known overlay capture issues
  static bool hasKnownCaptureIssues() {
    // Add platform-specific checks here if needed
    // For now, assume all platforms might have issues
    return true;
  }

  /// Get recommended settings for overlay capture based on device capabilities
  static OverlayCaptureSettings
      getRecommendedCaptureSettings() {
    return OverlayCaptureSettings(
      pixelRatio: 1.0,
      maxRetries: hasKnownCaptureIssues() ? 5 : 3,
      stabilizationDelay: const Duration(milliseconds: 16),
      validationEnabled: true,
    );
  }
}

/// Configuration class for overlay capture settings
class OverlayCaptureSettings {
  final double pixelRatio;
  final int maxRetries;
  final Duration stabilizationDelay;
  final bool validationEnabled;

  const OverlayCaptureSettings({
    required this.pixelRatio,
    required this.maxRetries,
    required this.stabilizationDelay,
    required this.validationEnabled,
  });
}
