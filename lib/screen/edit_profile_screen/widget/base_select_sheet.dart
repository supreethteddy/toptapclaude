import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toptap/common/widget/bottom_sheet_top_view.dart';
import 'package:toptap/common/widget/custom_search_text_field.dart';
import 'package:toptap/common/widget/text_button_custom.dart';
import 'package:toptap/languages/languages_keys.dart';
import 'package:toptap/utilities/color_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';
import 'package:toptap/utilities/theme_res.dart';

class BaseSelectSheet<T> extends StatelessWidget {
  final String title;
  final RxList<T> items;
  final Rx<T?> selectedItem;
  final String Function(T) getDisplayText;
  final TextStyle Function(T)? style;
  final String Function(T)? getSecondaryText;
  final Function(T) onSelect;
  final Function(String) onSearch;

  const BaseSelectSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedItem,
    required this.getDisplayText,
    this.getSecondaryText,
    required this.onSelect,
    required this.onSearch,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ClipSmoothRect(
        radius: const SmoothBorderRadius.vertical(
          top: SmoothRadius(
              cornerRadius: 15, cornerSmoothing: 1),
        ),
        child: Container(
          color: adaptiveBackground(context),
          child: Column(
            children: [
              BottomSheetTopView(
                  title: title, sideBtnVisibility: false),
              CustomSearchTextField(onChanged: onSearch),
              Expanded(
                child: Obx(() {
                  return ListView.builder(
                    itemCount: items.length,
                    padding: const EdgeInsets.only(top: 5),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Obx(() {
                        final isSelected =
                            selectedItem.value == item;
                        return _buildListItem(
                          item: item,
                          isSelected: isSelected,
                          onTap: () {
                            onSelect(item);
                          },
                          style: style?.call(item),
                          displayText: getDisplayText(item),
                          secondaryText:
                              getSecondaryText?.call(item),
                          context: context,
                        );
                      });
                    },
                  );
                }),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextButtonCustom(
                    title: LKey.save.tr,
                    onTap: () => Get.back(),
                    titleColor: adaptiveTextColor(context),
                    horizontalMargin: 0,
                    backgroundColor:
                        adaptiveBackground(context),
                    borderSide: BorderSide(
                        color: adaptiveTextColor(context)
                            .withValues(alpha: .3),
                        width: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildListItem<T>(
    {required T item,
    required bool isSelected,
    required VoidCallback onTap,
    required String displayText,
    TextStyle? style,
    String? secondaryText,
    required BuildContext context}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      color: isSelected
          ? adaptiveTextColor(context)
          : adaptiveBackground(context),
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 10),
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(
            displayText,
            style: style ??
                TextStyleCustom.outFitRegular400(
                    color: isSelected
                        ? themeAccentSolid(context)
                        : ColorRes.textlightGreenColor),
          )),
          const SizedBox(width: 20),
          if (secondaryText != null) ...[
            Text(
              secondaryText,
              style: TextStyleCustom.outFitRegular400(
                color: isSelected
                    ? themeAccentSolid(context)
                    : ColorRes.textlightGreenColor,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
