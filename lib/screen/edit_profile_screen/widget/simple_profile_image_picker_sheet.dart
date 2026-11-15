import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toptap/common/functions/media_picker_helper.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class SimpleProfileImagePickerSheet
    extends StatelessWidget {
  final Function(XFile) onImageSelected;

  const SimpleProfileImagePickerSheet(
      {super.key, required this.onImageSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: adaptiveBackground(context),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin:
                  const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: textLightGrey(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20),
              child: Text(
                LKey.selectProfileImage.tr,
                style: TextStyleCustom.outFitMedium500(
                  color: textDarkGrey(context),
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Options
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20),
              child: Column(
                children: [
                  // Camera option
                  _buildOption(
                    context,
                    icon: Icons.camera_alt,
                    title: LKey.camera.tr,
                    subtitle: "Take a new photo",
                    onTap: () => _pickFromCamera(),
                  ),

                  const SizedBox(height: 12),

                  // Gallery option
                  _buildOption(
                    context,
                    icon: Icons.photo_library,
                    title: LKey.gallery.tr,
                    subtitle: "Choose from gallery",
                    onTap: () => _pickFromGallery(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
              color: adaptiveBorderColor(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: themeAccentSolid(context)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: themeAccentSolid(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyleCustom.outFitMedium500(
                      color: textDarkGrey(context),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyleCustom.outFitRegular400(
                      color: textLightGrey(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: textLightGrey(context),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _pickFromCamera() async {
    try {
      Get.back(); // Close the bottom sheet

      Loggers.info('📸 Starting camera picker...');
      final XFile? image =
          await MediaPickerHelper.shared.pickImage(
        source: ImageSource.camera,
      );

      if (image != null) {
        Loggers.info(
            '📸 Camera image selected: ${image.path}');
        await _processSelectedImage(image);
      } else {
        Loggers.warning('⚠️ No camera image selected');
      }
    } catch (e) {
      Loggers.error('❌ Camera picker error: $e');
    }
  }

  void _pickFromGallery() async {
    try {
      Get.back(); // Close the bottom sheet

      Loggers.info('🖼️ Starting gallery picker...');
      final XFile? image =
          await MediaPickerHelper.shared.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        Loggers.info(
            '🖼️ Gallery image selected: ${image.path}');
        await _processSelectedImage(image);
      } else {
        Loggers.warning('⚠️ No gallery image selected');
      }
    } catch (e) {
      Loggers.error('❌ Gallery picker error: $e');
    }
  }

  Future<void> _processSelectedImage(
      XFile imageFile) async {
    try {
      Loggers.info(
          '🔄 Processing selected image: ${imageFile.path}');

      // Compress the image directly (without cropping for now)
      final XFile? compressedFile = await MediaPickerHelper
          .shared
          .compressProfileImage(imageFile.path);

      if (compressedFile != null) {
        Loggers.info('✅ Image compressed successfully');
        onImageSelected(compressedFile);
        final fileSize = await compressedFile.length();
        Loggers.info(
            "Compressed image size: ${fileSize / 1024} KB");
      } else {
        Loggers.warning(
            '⚠️ Compression failed, using original file');
        onImageSelected(imageFile);
      }
    } catch (e) {
      Loggers.error('❌ Failed to process image: $e');
      // Fallback to original image
      onImageSelected(imageFile);
    }
  }
}
