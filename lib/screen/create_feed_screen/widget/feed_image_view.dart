import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/custom_page_indicator.dart';
import 'package:toptap/screen/color_filter_screen/color_filter_screen.dart';
import 'package:toptap/screen/create_feed_screen/create_feed_screen_controller.dart';
import 'package:toptap/utilities/app_res.dart';

class FeedImageView extends StatelessWidget {
  final RxList<ImageWithFilter> files;
  final CreateFeedScreenController controller;

  const FeedImageView(
      {super.key,
      required this.files,
      required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        return files.isEmpty
            ? const SizedBox()
            : Container(
                height: Get.height *
                    0.4, // Increased to 40% for better visibility
                width: Get.width,
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Enhanced Image PageView with better fit
                      PageView.builder(
                          itemCount: files.length,
                          onPageChanged: (value) {
                            controller.selectedImageIndex
                                .value = value;
                          },
                          itemBuilder: (context, index) {
                            ImageWithFilter file =
                                files[index];
                            return file
                                    .colorFilter.isNotEmpty
                                ? ColorFiltered(
                                    colorFilter: ColorFilter
                                        .matrix(file
                                            .colorFilter),
                                    child: _file(
                                        file.media.path))
                                : _file(file.media.path);
                          }),

                      // Gradient overlay for better button visibility
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black
                                    .withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Top control buttons
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (files.length <
                                (controller.setting.value
                                        ?.maxImagesPerPost ??
                                    AppRes.imageLimit))
                              Container(
                                margin:
                                    const EdgeInsets.only(
                                        right: 8),
                                child: _buildControlButton(
                                  icon: Icons.add,
                                  onTap: controller
                                      .selectImages,
                                ),
                              ),
                            _buildControlButton(
                              icon: Icons.delete_outline,
                              onTap: controller
                                  .onDeleteSelectedImages,
                              color: Colors.red
                                  .withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),

                      // Bottom gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black
                                    .withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom controls
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            // Image counter (left side)
                            if (files.length > 1)
                              Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 12,
                                    vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withOpacity(0.7),
                                  borderRadius:
                                      BorderRadius.circular(
                                          20),
                                ),
                                child: Text(
                                  '${controller.selectedImageIndex.value + 1}/${files.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w500,
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            // Page indicator (center)
                            if (files.length > 1)
                              Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 8,
                                    vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withOpacity(0.5),
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                ),
                                child: CustomPageIndicator(
                                    length: files.length,
                                    selectedIndex: controller
                                        .selectedImageIndex),
                              )
                            else
                              const SizedBox.shrink(),

                            // Filter button (right side)
                            _buildControlButton(
                              icon: Icons.tune,
                              onTap: () {
                                Get.bottomSheet(
                                  ColorFilterScreen(
                                    images: files,
                                    onChanged: (items) {
                                      files.value = items;
                                      files.refresh();
                                    },
                                    mediaType:
                                        MediaType.image,
                                  ),
                                  isScrollControlled: true,
                                  ignoreSafeArea: false,
                                );
                              },
                              color: Colors.blue
                                  .withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color ?? Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _file(String path) {
    return Image.file(
      File(path),
      height:
          Get.height * 0.35, // Match the container height
      width: Get.width,
      fit: BoxFit.contain,
    );
  }
}
