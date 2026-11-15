import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dismissible_page/dismissible_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:toptap/common/extensions/string_extension.dart';
import 'package:toptap/utilities/theme_res.dart';

class ProfileImageViewer extends StatelessWidget {
  final String? networkImageUrl;
  final XFile? localImageFile;
  final String? fullName;

  const ProfileImageViewer({
    super.key,
    this.networkImageUrl,
    this.localImageFile,
    this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return DismissiblePage(
      onDismissed: () {
        Get.back();
      },
      direction: DismissiblePageDismissDirection.multi,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close,
                color: Colors.white),
            onPressed: () => Get.back(),
          ),
          title: Text(
            fullName ?? 'Profile Image',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Hero(
            tag:
                'profile_image_${networkImageUrl ?? localImageFile?.path}',
            child: PhotoView(
              imageProvider: _getImageProvider(),
              minScale: PhotoViewComputedScale.contained,
              backgroundDecoration:
                  const BoxDecoration(color: Colors.black),
              maxScale:
                  PhotoViewComputedScale.covered * 2.0,
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  color: adaptiveTextColor(context),
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded /
                          (event.expectedTotalBytes ?? 1),
                ),
              ),
              errorBuilder: (context, error, stackTrace) =>
                  Center(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        color:
                            Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider _getImageProvider() {
    if (localImageFile != null) {
      return FileImage(File(localImageFile!.path));
    } else if (networkImageUrl != null &&
        networkImageUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(
          networkImageUrl!.addBaseURL());
    } else {
      // Fallback to a placeholder or default image
      return const AssetImage(
          'assets/images/default_avatar.png');
    }
  }
}
