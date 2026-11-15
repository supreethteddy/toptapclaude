import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toptap/common/functions/media_picker_helper.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class ProfileImagePickerSheet extends StatelessWidget {
  final Function(XFile) onImageSelected;

  const ProfileImagePickerSheet(
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
                    onTap: () => _pickFromCamera(context),
                  ),

                  const SizedBox(height: 12),

                  // Gallery option
                  _buildOption(
                    context,
                    icon: Icons.photo_library,
                    title: LKey.gallery.tr,
                    subtitle: "Choose from gallery",
                    onTap: () => _pickFromGallery(context),
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

  void _pickFromCamera(BuildContext context) async {
    try {
      // Store theme values before async operations
      final accentColor = themeAccentSolid(context);

      Loggers.info('📸 Starting camera picker...');
      final XFile? image =
          await MediaPickerHelper.shared.pickImage(
        source: ImageSource.camera,
      );

      if (image != null) {
        Loggers.info(
            '📸 Camera image selected: ${image.path}');
        // Don't close the sheet yet - wait for cropping to complete
        await _cropImageWithStoredTheme(image, accentColor);
      } else {
        Loggers.warning('⚠️ No camera image selected');
        Get.back(); // Close the sheet only if no image was selected
      }
    } catch (e) {
      Loggers.error('❌ Camera picker error: $e');
      _showErrorAndClose(
          'Failed to access camera. Please check permissions.');
    }
  }

  void _pickFromGallery(BuildContext context) async {
    try {
      // Store theme values before async operations
      final accentColor = themeAccentSolid(context);

      Loggers.info('🖼️ Starting gallery picker...');
      final XFile? image =
          await MediaPickerHelper.shared.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        Loggers.info(
            '🖼️ Gallery image selected: ${image.path}');
        // Don't close the sheet yet - wait for cropping to complete
        await _cropImageWithStoredTheme(image, accentColor);
      } else {
        Loggers.warning('⚠️ No gallery image selected');
        Get.back(); // Close the sheet only if no image was selected
      }
    } catch (e) {
      Loggers.error('❌ Gallery picker error: $e');
      _showErrorAndClose(
          'Failed to access gallery. Please check permissions.');
    }
  }

  void _showErrorAndClose(String message) {
    Get.back(); // Close the sheet first
    Get.snackbar(
      'Error',
      message,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
    );
  }

  Future<void> _cropImageWithStoredTheme(
      XFile imageFile, Color accentColor) async {
    try {
      Loggers.info(
          '✂️ Starting image crop for: ${imageFile.path}');

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(
            ratioX: 1, ratioY: 1), // Square crop
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Image',
            toolbarColor: accentColor,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: accentColor,
            dimmedLayerColor:
                Colors.black.withValues(alpha: 0.8),
            cropFrameColor: accentColor,
            cropGridColor:
                Colors.white.withValues(alpha: 0.5),
            cropFrameStrokeWidth: 2,
            cropGridStrokeWidth: 1,
            showCropGrid: true,
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
          IOSUiSettings(
            title: 'Crop Profile Image',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
          WebUiSettings(
            context: Get.context!,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(
              width: 520,
              height: 520,
            ),
          ),
        ],
      );

      if (croppedFile != null) {
        Loggers.info(
            '✅ Image cropped successfully: ${croppedFile.path}');

        // Compress the cropped image
        final XFile? compressedFile =
            await MediaPickerHelper.shared
                .compressProfileImage(croppedFile.path);

        if (compressedFile != null) {
          Loggers.info('✅ Image compressed successfully');
          onImageSelected(compressedFile);
          final fileSize = await compressedFile.length();
          Loggers.info(
              "Cropped and compressed image size: ${fileSize / 1024} KB");
        } else {
          Loggers.warning(
              '⚠️ Compression failed, using original cropped file');
          onImageSelected(XFile(croppedFile.path));
        }

        // Close the bottom sheet only after successful cropping and compression
        Get.back();
      } else {
        Loggers.warning(
            '⚠️ Image cropping was cancelled or failed');
        // Close the sheet if user cancelled cropping
        Get.back();
      }
    } catch (e) {
      Loggers.error('❌ Failed to crop image: $e');
      // Close the sheet on error
      Get.back();
    }
  }
}
