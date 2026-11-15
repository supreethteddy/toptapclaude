import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/loader_widget.dart';
import 'package:toptap/model/sticker/sticker_model.dart';
import 'package:toptap/screen/sticker_sheet/sticker_sheet_controller.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class StickerSheet extends StatelessWidget {
  StickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StickerSheetController(),
        tag: DateTime.now()
            .millisecondsSinceEpoch
            .toString());

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: adaptiveBackground(context),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          _buildHandleBar(context),

          // Title
          _buildTitle(context),

          // Search bar
          _buildSearchBar(controller, context),

          // Category tabs
          //  _buildCategoryTabs(controller, context),

          // Sticker grid
          Expanded(
            child: _buildStickerGrid(controller, context),
          ),
        ],
      ),
    );
  }

  Widget _buildHandleBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: adaptiveTextColor(context).withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Stickers',
            style: TextStyleCustom.outFitSemiBold600(
              fontSize: 20,
              color: adaptiveTextColor(context),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                color: adaptiveTextColor(context)),
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(StickerSheetController controller,
      BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10),
      child: TextField(
        onChanged: controller.searchStickers,
        style: TextStyleCustom.outFitRegular400(
          color: adaptiveTextColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Search stickers...',
          hintStyle: TextStyleCustom.outFitRegular400(
            color:
                adaptiveTextColor(context).withOpacity(0.5),
          ),
          prefixIcon: Icon(Icons.search,
              color: adaptiveTextColor(context)),
          filled: true,
          fillColor:
              adaptiveTextColor(context).withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(
      StickerSheetController controller,
      BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: controller.categories.length,
        itemBuilder: (context, index) {
          final category = controller.categories[index];

          return Obx(() {
            final isSelected =
                controller.selectedCategory.value ==
                    category;

            return GestureDetector(
              onTap: () =>
                  controller.loadCategory(category),
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 5),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? themeAccentSolid(context)
                      : adaptiveTextColor(context)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyleCustom.outFitMedium500(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : adaptiveTextColor(context),
                    ),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildStickerGrid(
      StickerSheetController controller,
      BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: LoaderWidget());
      }

      if (controller.stickers.isEmpty) {
        return Center(
          child: Text(
            'No stickers found',
            style: TextStyleCustom.outFitRegular400(
              fontSize: 16,
              color: adaptiveTextColor(context)
                  .withOpacity(0.5),
            ),
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: controller.stickers.length,
        itemBuilder: (context, index) {
          final sticker = controller.stickers[index];
          return _buildStickerItem(
              sticker, controller, context);
        },
      );
    });
  }

  Widget _buildStickerItem(
    StickerModel sticker,
    StickerSheetController controller,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () => controller.onStickerSelected(sticker),
      child: Container(
        decoration: BoxDecoration(
          color:
              adaptiveTextColor(context).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: sticker.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(
              child:
                  CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.broken_image,
              color: adaptiveTextColor(context)
                  .withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }
}
