import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/manager/haptic_manager.dart';
import 'package:toptap/common/widget/confirmation_dialog.dart';
import 'package:toptap/common/widget/draggable_sticker_widget.dart';
import 'package:toptap/common/widget/drawing_canvas_widget.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/screen/camera_edit_screen/camera_edit_screen_controller.dart';
import 'package:toptap/screen/camera_edit_screen/text_story/story_text_view_controller.dart';
import 'package:toptap/screen/camera_edit_screen/text_story/widget/text_editor_sheet.dart';
import 'package:toptap/screen/camera_screen/camera_types.dart'
    as camera_types;
import 'package:toptap/utilities/text_style_custom.dart';

class CameraEditImageView extends StatelessWidget {
  final CameraEditScreenController cameraEditController;

  const CameraEditImageView(
      {super.key, required this.cameraEditController});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
        StoryTextViewController(cameraEditController));
    return Obx(
      () {
        // Retrieve the selected background style once to avoid repetitive computation
        camera_types.PostStoryContent content =
            cameraEditController.content.value;
        bool isTextStory = content.type ==
            camera_types.PostStoryContentType.storyText;
        var gradient =
            cameraEditController.storyGradientColor[
                cameraEditController.selectedBgIndex.value];
        List<double> filter =
            cameraEditController.selectedFilter.value;

        return Container(
          decoration: ShapeDecoration(
            shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                    cornerRadius: 10, cornerSmoothing: 1)),
          ),
          child: RepaintBoundary(
            key: controller.previewContainer,
            child: Stack(
              clipBehavior: Clip
                  .none, // FIXED: Allow text to render on top without clipping
              children: [
                // FIXED: Wrap background in IgnorePointer so it doesn't block text widget gestures
                IgnorePointer(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(filter),
                    child: Container(
                      width:
                          MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context)
                          .size
                          .height,
                      decoration: ShapeDecoration(
                        shape: SmoothRectangleBorder(
                            borderRadius:
                                SmoothBorderRadius(
                                    cornerRadius: 10,
                                    cornerSmoothing: 1)),
                        // color: content.bgColor,
                        gradient: isTextStory
                            ? gradient
                            : content.bgGradient,
                      ),
                      child: ClipSmoothRect(
                        radius: SmoothBorderRadius(
                            cornerRadius: 10,
                            cornerSmoothing: 1),
                        child: Stack(
                          children: [
                            if (content.type ==
                                camera_types
                                    .PostStoryContentType
                                    .storyImage)
                              Align(
                                  alignment:
                                      Alignment.center,
                                  child: Image.file(
                                      File(
                                          content.content ??
                                              ''),
                                      width:
                                          double.infinity,
                                      fit:
                                          BoxFit.fitWidth)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ...controller.textWidgets.asMap().map(
                  (i, element) {
                    return MapEntry(
                        i,
                        DraggableTextWidget(
                          key: Key(element
                              .id), // CRITICAL FIX: Use unique ID as key to prevent duplicate keys error
                          data: element,
                          onUpdate: (updatedData) {
                            // FIXED: Use ID-based updates to prevent text interference
                            controller.updateTextWidgetById(
                                element.id, updatedData);
                          },
                          onDelete: () {
                            // FIXED: Use ID-based deletion for more reliable text management
                            controller.deleteTextWidgetById(
                                element.id);
                          },
                        ));
                  },
                ).values,
                // Stickers layer - wrapped in Obx for reactive updates
                Obx(() {
                  return Stack(
                    children: cameraEditController.stickers
                        .map((sticker) {
                      return Obx(() {
                        final isSelected =
                            cameraEditController
                                    .selectedSticker
                                    .value
                                    ?.id ==
                                sticker.id;
                        final hideControls =
                            cameraEditController
                                .hideStickerControls.value;
                        return DraggableStickerWidget(
                          key: Key(sticker.id),
                          positionedSticker: sticker,
                          isSelected: isSelected,
                          hideControls: hideControls,
                          onTap: () => cameraEditController
                              .selectSticker(sticker),
                          onUpdate: cameraEditController
                              .updateSticker,
                          onDelete: () =>
                              cameraEditController
                                  .deleteSticker(
                                      sticker.id),
                        );
                      });
                    }).toList(),
                  );
                }),
                // Drawing layer - ALWAYS show strokes, only accept input in drawing mode
                Obx(() {
                  final isDrawingMode = cameraEditController
                      .isDrawingMode.value;
                  return IgnorePointer(
                    ignoring:
                        !isDrawingMode, // Block touches when NOT in drawing mode
                    child: DrawingCanvas(
                      strokes: cameraEditController
                          .drawingStrokes,
                      color: cameraEditController
                          .selectedDrawColor.value,
                      strokeWidth: cameraEditController
                          .brushSize.value,
                      isEraser: cameraEditController
                          .isEraser.value,
                      isActive:
                          isDrawingMode, // Pass drawing mode state
                      onStrokeCompleted:
                          cameraEditController
                              .addDrawingStroke,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DraggableTextWidget extends StatefulWidget {
  final TextWidgetData data;
  final Function(TextWidgetData updatedData) onUpdate;
  final VoidCallback onDelete;

  const DraggableTextWidget({
    super.key,
    required this.data,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<DraggableTextWidget> createState() =>
      _DraggableTextWidgetState();
}

class _DraggableTextWidgetState
    extends State<DraggableTextWidget> {
  double _baseFontScale = 1.0;
  double _initialRotationAngle =
      0.0; // Initial rotation angle when scaling starts
  Offset _initialFocalPoint =
      Offset.zero; // Initial focal point for panning
  Offset _initialPosition = Offset
      .zero; // Position of the text when scaling starts
  // REMOVED: _controller variable as it's no longer needed after fixing text editing logic
  bool _isViewVisible = true;

  void onScaleStart(ScaleStartDetails details) {
    setState(() {
      _baseFontScale = widget.data.fontScale;
      _initialFocalPoint = details.focalPoint;
      _initialPosition =
          Offset(widget.data.left, widget.data.top);
      _initialRotationAngle = widget.data.fontAngle;
    });
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Update position (panning) - FIXED: More responsive positioning
      final Offset delta =
          details.focalPoint - _initialFocalPoint;
      double leftX = _initialPosition.dx +
          delta.dx; // Remove division for 1:1 tracking
      double topY = _initialPosition.dy +
          delta.dy; // Remove division for 1:1 tracking

      // Constrain position to screen bounds - IMPROVED: More generous boundaries for better text movement
      leftX = leftX.clamp(
          -100.0,
          Get.width +
              50); // Allow text to go further off-screen
      topY = topY.clamp(
          -50.0,
          Get.height +
              50); // Allow text to move more freely

      // Update font scale (scaling)
      double fontScale = (_baseFontScale * details.scale)
          .clamp(0.2, 3.0); // Limit max scale

      // Update rotation angle
      double rotationAngle =
          _initialRotationAngle + details.rotation;

      // Notify parent of changes - FIXED: Preserve original ID to prevent text interference
      widget.onUpdate(TextWidgetData(
          id: widget.data
              .id, // CRITICAL: Preserve the original ID
          text: widget.data.text,
          top: topY,
          left: leftX,
          fontSize: widget.data.fontSize,
          fontScale: fontScale,
          fontAngle: rotationAngle,
          fontColor: widget.data.fontColor,
          fontAlign: widget.data.fontAlign,
          googleFontFamily: widget.data.googleFontFamily,
          opacity: widget.data.opacity));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.data.left,
      top: widget.data.top,
      child: GestureDetector(
        onTap: openTextEditor,
        onLongPress: () {
          HapticManager.shared.light();
          Get.bottomSheet(ConfirmationSheet(
            title: LKey.delete.tr,
            description: LKey.deleteTextConfirmation.tr,
            onTap: widget.onDelete,
          ));
        },
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(widget.data.fontAngle)
            ..scale(widget.data.fontScale),
          child: Container(
            width: Get.width - 50,
            color: Colors.transparent,
            constraints: const BoxConstraints(
                minWidth: 100, minHeight: 50),
            child: Text(
              _isViewVisible ? widget.data.text : '',
              style: _getTextStyle(
                  widget.data.googleFontFamily,
                  widget.data.fontSize,
                  widget.data.fontColor,
                  widget.data.opacity),
              textAlign: widget.data.fontAlign.align,
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _getTextStyle(GoogleFontFamily? font,
      double fontSize, Color color, double opacity) {
    return font?.style.copyWith(
          fontSize: fontSize,
          color: color.withValues(alpha: opacity),
        ) ??
        TextStyleCustom.outFitMedium500(
            fontSize: fontSize,
            color: color,
            opacity: opacity);
  }

  void openTextEditor() {
    _isViewVisible = false;
    setState(() {});
    Get.bottomSheet<TextWidgetData>(
            TextEditorSheet(data: widget.data),
            isScrollControlled: true,
            ignoreSafeArea: false,
            // backgroundColor: textVeryLightGrey(context).withValues(alpha: 1),
            enableDrag: false,
            isDismissible: false,
            // barrierColor: textVeryLightGrey(context).withValues(alpha: 1),
            persistent: false)
        .then((value) {
      _isViewVisible = true;
      setState(() {});
      if (value != null) {
        // FIXED: Just update the existing text instead of delete/add cycle
        // This was causing text duplication and persistence issues
        widget.onUpdate(value);
        // REMOVED: widget.onDelete() and _controller.textWidgets.add(value)
        // The onUpdate callback should handle updating the text in the list
      }
    });
  }
}
