import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:toptap/common/controller/base_controller.dart';
import 'package:toptap/common/functions/generate_color.dart';
import 'package:toptap/common/manager/logger.dart';
import 'package:toptap/screen/camera_edit_screen/camera_edit_screen_controller.dart';
import 'package:toptap/screen/camera_edit_screen/text_story/widget/story_text_font_widget.dart';
import 'package:toptap/screen/camera_edit_screen/text_story/widget/text_editor_sheet.dart';
import 'package:toptap/utilities/app_res.dart';
import 'package:toptap/utilities/asset_res.dart';
import 'package:toptap/utilities/text_style_custom.dart';

enum BgColorType { color, gradient }

class TextEditor {
  String image;
  String title;

  TextEditor({required this.image, required this.title});
}

class GoogleFontFamily {
  final String fontName;
  TextStyle? _style; // Lazy-loaded style

  GoogleFontFamily({required this.fontName});

  // Lazy getter to fetch style only when needed
  TextStyle get style {
    _style ??= GoogleFonts.getFont(
        fontName); // Load only when accessed
    return _style ?? TextStyleCustom.outFitRegular400();
  }

  // Release memory manually
  void clearCache() {
    _style = null; // Remove stored TextStyle
  }
}

enum FontAlign {
  start,
  center,
  end,
  justify;

  static const Map<FontAlign, IconData> _iconMap = {
    FontAlign.start: Icons.format_align_left_rounded,
    FontAlign.center: Icons.format_align_center_rounded,
    FontAlign.end: Icons.format_align_right_rounded,
    FontAlign.justify: Icons.format_align_justify_rounded,
  };

  static const Map<FontAlign, TextAlign> _alignMap = {
    FontAlign.start: TextAlign.left,
    FontAlign.center: TextAlign.center,
    FontAlign.end: TextAlign.end,
    FontAlign.justify: TextAlign.justify,
  };

  IconData get icon => _iconMap[this]!;

  TextAlign get align => _alignMap[this]!;
}

enum StoryTextEditor {
  font,
  style,
  color,
  opacity;
  // textSize;

  static const Map<StoryTextEditor, String> imageMap = {
    StoryTextEditor.font: AssetRes.icTextFont,
    StoryTextEditor.style: AssetRes.icTextStyle,
    StoryTextEditor.color: AssetRes.icTextColor,
    StoryTextEditor.opacity: AssetRes.icTextOpacity,
    // StoryTextEditor.textSize: AssetRes.icTextSize,
  };

  static const Map<StoryTextEditor, String> titleMap = {
    StoryTextEditor.font: 'Font',
    StoryTextEditor.style: 'Style',
    StoryTextEditor.color: 'Color',
    StoryTextEditor.opacity: 'Opacity',
    // StoryTextEditor.textSize: 'Size',
  };

  String get image => imageMap[this]!;

  String get title => titleMap[this]!;
}

class StoryTextViewController extends BaseController {
  List<StoryTextEditor> editorList = StoryTextEditor.values;
  List<FontAlign> alignList = FontAlign.values;

  RxList<GoogleFontFamily> fontFamilyList =
      <GoogleFontFamily>[].obs;
  RxList<GoogleFontFamily> filteredFontFamilyList =
      <GoogleFontFamily>[].obs;

  RxList<GoogleFontFamily> outerFontFamilyList =
      <GoogleFontFamily>[].obs;
  Rx<Color> selectedColor =
      Rx(GenerateColor.instance.fontColor.first);
  RxInt selectedIndex = 0.obs;

  RxList<TextWidgetData> textWidgets =
      <TextWidgetData>[].obs;

  Rx<StoryTextEditor> selectorEditorIndex =
      Rx<StoryTextEditor>(StoryTextEditor.font);
  Rx<GoogleFontFamily?> selectedFontFamily =
      Rx<GoogleFontFamily?>(null);
  GlobalKey previewContainer = GlobalKey();
  Rx<FontAlign> selectedAlignment = Rx(FontAlign.center);
  RxDouble selectedTextOpacity = 1.0.obs;
  RxDouble selectedFontSize = AppRes.minFontSize.obs;

  CameraEditScreenController cameraEditController;

  StoryTextViewController(this.cameraEditController);
  @override
  void onReady() {
    super.onReady();
    cameraEditController.onNewTexFieldAdd = () {
      openTextEditor(context: Get.context!);
    };
    _addFontFamilyList();
  }

  @override
  void onClose() {
    super.onClose();
    releaseAllFonts();
  }

  void _addFontFamilyList() {
    final googleFontsMap = GoogleFonts.asMap();

    // Load only the first 10 fonts to reduce memory usage
    outerFontFamilyList.assignAll(googleFontsMap.entries
        .take(10)
        .map((font) => GoogleFontFamily(fontName: font.key))
        .toList());

    // Keep the full font list empty initially, load only when required
    fontFamilyList.clear();
    filteredFontFamilyList.clear();

    Future.delayed(const Duration(seconds: 1), () {
      loadAllFonts();
    });
  }

  void loadAllFonts() {
    if (fontFamilyList.isEmpty) {
      final googleFontsMap = GoogleFonts.asMap();

      // Convert map keys to a list to reduce object creation
      final fontList = googleFontsMap.keys
          .map((fontName) =>
              GoogleFontFamily(fontName: fontName))
          .toList(
              growable:
                  false); // Use non-growable list to reduce memory overhead
      Loggers.success(fontList.length);
      fontFamilyList.assignAll(fontList);
      filteredFontFamilyList.assignAll(fontList);
    }
  }

  void openTextEditor(
      {required BuildContext context,
      TextWidgetData? existingData}) async {
    print(
        '🎨 Opening text editor with existing data: ${existingData?.text ?? "null"}');

    // CRITICAL FIX: Reset editor values FIRST before creating new data
    resetTextEditorValues();

    TextWidgetData dataToEdit = existingData ??
        TextWidgetData(
          id:  Uuid()
              .v4(), // FIXED: Remove const to generate unique UUIDs
          text:
              '', // CRITICAL: Start with empty text for new elements
          top: 0.5,
          left: 0.5,
          fontScale: 1.0,
          fontAngle: 0.0,
          fontSize: selectedFontSize.value,
          opacity: selectedTextOpacity.value,
          googleFontFamily: selectedFontFamily.value,
          fontAlign: selectedAlignment.value,
          fontColor: selectedColor.value,
        );

    print(
        '📝 TextEditor initialized with text: "${dataToEdit.text}" and ID: ${dataToEdit.id}');

    // Set editor values from the data being edited
    selectedFontSize.value = dataToEdit.fontSize;
    selectedTextOpacity.value = dataToEdit.opacity;
    selectedFontFamily.value = dataToEdit.googleFontFamily;
    selectedColor.value = dataToEdit.fontColor;
    selectedAlignment.value = dataToEdit.fontAlign;

    final result = await Get.bottomSheet(
      TextEditorSheet(
        data: dataToEdit,
      ),
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
    );

    if (result != null && result is TextWidgetData) {
      print(
          '✅ Text editor returned data: "${result.text}" with ID: ${result.id}');

      if (existingData != null) {
        // Update existing text widget
        final targetIndex = textWidgets.indexWhere(
            (element) => element.id == existingData.id);
        if (targetIndex != -1) {
          textWidgets[targetIndex] = result;
          print(
              '📝 Updated existing text widget at index $targetIndex');
        }
      } else {
        // Add new text widget
        textWidgets.add(result);
        print('➕ Added new text widget: "${result.text}"');
      }
    }
  }

  void resetTextEditorValues() {
    // FIXED: Complete reset of all editor values to default state
    selectedFontFamily.value = null;
    selectedColor.value = Colors.white;
    selectedAlignment.value = FontAlign.center;
    selectedTextOpacity.value = 1.0;
    selectedFontSize.value = AppRes.minFontSize;
    selectorEditorIndex.value = StoryTextEditor.font;
    print('🔄 Text editor values reset to defaults');
  }

  // Helper to create updated text widget data - FIXED: Preserve original ID
  TextWidgetData createUpdatedData(
      TextWidgetData data, String updatedText) {
    return TextWidgetData(
      id: data
          .id, // CRITICAL: Preserve the original ID to prevent text interference
      text: updatedText,
      top: data.top,
      left: data.left,
      fontScale: data.fontScale,
      fontAngle: data.fontAngle,
      fontSize: selectedFontSize.value,
      opacity: selectedTextOpacity.value,
      googleFontFamily: selectedFontFamily.value,
      fontAlign: selectedAlignment.value,
      fontColor: selectedColor.value,
    );
  }

  void updateTextWidget(
      int index, TextWidgetData updatedData) {
    // CRITICAL FIX: Add bounds checking to prevent crashes from shared controllers
    if (index < 0 || index >= textWidgets.length) {
      print(
          '⚠️ WARNING: updateTextWidget called with invalid index $index (length: ${textWidgets.length})');
      return;
    }

    // FIXED: Use ID-based updates instead of index to prevent cross-text interference
    final targetId = textWidgets[index].id;
    final targetIndex = textWidgets
        .indexWhere((element) => element.id == targetId);
    if (targetIndex != -1) {
      textWidgets[targetIndex] = updatedData;
    }
  }

  // IMPROVED: Add ID-based update method for better text management
  void updateTextWidgetById(
      String id, TextWidgetData updatedData) {
    final index = textWidgets
        .indexWhere((element) => element.id == id);
    if (index != -1) {
      textWidgets[index] = updatedData;
    }
  }

  void deleteTextWidget(int index) {
    if (index >= 0 && index < textWidgets.length) {
      textWidgets.removeAt(index);
    }
  }

  // IMPROVED: Add ID-based delete method
  void deleteTextWidgetById(String id) {
    textWidgets.removeWhere((element) => element.id == id);
  }

  void onChangeBg() {
    selectedIndex.value = (selectedIndex.value + 1) %
        GenerateColor.instance.gradientList.length;
  }

  onEditorTap(StoryTextEditor index) {
    selectorEditorIndex.value = index;
  }

  void onFontFamilySelect(
      GoogleFontFamily fontFamily, int type) {
    if (selectedFontFamily.value != fontFamily) {
      selectedFontFamily.value = fontFamily;
    } else {
      selectedFontFamily.value = null;
    }

    if (type == 1) {
      outerFontFamilyList
        ..removeWhere(
            (e) => e.fontName == fontFamily.fontName)
        ..insert(0, fontFamily);
    }
  }

  onSearchFontFamily(String value) {
    if (value.isEmpty) {
      // If query is empty, restore the original list
      filteredFontFamilyList.assignAll(fontFamilyList);
    } else {
      // Filter fontFamilyList based on the query
      filteredFontFamilyList.assignAll(fontFamilyList
          .where((font) => font.fontName
              .toLowerCase()
              .contains((value).toLowerCase()))
          .toList());
    }
  }

  void openFontSheet() async {
    Get.bottomSheet(const GoogleFontFamilySheet(),
            isScrollControlled: true, ignoreSafeArea: false)
        .then((value) {
      onSearchFontFamily('');
    });
  }

  // Call this when fonts are no longer needed to free memory
  void releaseAllFonts() {
    Loggers.success('Releasing fonts');
    for (var font in fontFamilyList) {
      font.clearCache(); // Clear cached styles
    }
    fontFamilyList.clear(); // Remove font list from memory
    filteredFontFamilyList.clear();
  }
}
