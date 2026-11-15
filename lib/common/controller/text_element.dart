import 'package:flutter/material.dart';
import 'package:toptap/common/utilities/safe_data_extractor.dart';
import 'dart:math';

/// Generates a unique ID for text elements
String generateTextElementId() {
  final random = Random();
  final timestamp = DateTime.now()
      .microsecondsSinceEpoch; // More precise timestamp
  final randomNumber1 = random.nextInt(999999);
  final randomNumber2 = random.nextInt(999999);
  final id =
      'text_${timestamp}_${randomNumber1}_${randomNumber2}';

  // Debug logging to track ID generation
  print('🆔 Generated new text element ID: $id');

  return id;
}

/// Enhanced text alignment options
enum TextAlignment {
  left(TextAlign.left, Icons.format_align_left),
  center(TextAlign.center, Icons.format_align_center),
  right(TextAlign.right, Icons.format_align_right);

  const TextAlignment(this.align, this.icon);
  final TextAlign align;
  final IconData icon;
}

/// Google Font Family representation
class FontFamily {
  final String name;
  final String fontFamily;
  final TextStyle style;

  const FontFamily({
    required this.name,
    required this.fontFamily,
    required this.style,
  });
}

/// Represents an enhanced text element with advanced styling capabilities
class TextElement {
  /// The text content
  final String text;

  /// Position on the screen (center point)
  final Offset position;

  /// Scale factor for the text size
  final double scale;

  /// Rotation angle in radians
  final double rotation;

  /// Text color
  final Color color;

  /// Font size (base size before scaling)
  final double fontSize;

  /// Font weight
  final FontWeight fontWeight;

  /// Font family (Google Fonts support)
  final String? fontFamily;

  /// Text alignment
  final TextAlignment alignment;

  /// Text opacity (0.0 to 1.0)
  final double opacity;

  /// Google Font style (for advanced typography)
  final TextStyle? googleFontStyle;

  /// Unique identifier
  final String id;

  /// Whether this element is currently selected
  final bool isSelected;

  const TextElement({
    required this.text,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color = Colors.white,
    this.fontSize = 24.0,
    this.fontWeight = FontWeight.normal,
    this.fontFamily,
    this.alignment = TextAlignment.center,
    this.opacity = 1.0,
    this.googleFontStyle,
    required this.id, // Make ID required to ensure unique IDs
    this.isSelected = false,
  });

  /// Create a copy with updated properties
  TextElement copyWith({
    String? text,
    Offset? position,
    double? scale,
    double? rotation,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    String? fontFamily,
    TextAlignment? alignment,
    double? opacity,
    TextStyle? googleFontStyle,
    String? id,
    bool? isSelected,
  }) {
    return TextElement(
      text: text ?? this.text,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      alignment: alignment ?? this.alignment,
      opacity: opacity ?? this.opacity,
      googleFontStyle:
          googleFontStyle ?? this.googleFontStyle,
      id: id ?? this.id,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Get the enhanced text style for rendering
  TextStyle get textStyle {
    // Use Google Font style if available, otherwise fall back to standard styling
    final baseStyle = googleFontStyle ??
        TextStyle(
          fontFamily: fontFamily,
          fontWeight: fontWeight,
        );

    return baseStyle.copyWith(
      color: color.withOpacity(opacity),
      fontSize: fontSize * scale,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.5),
          offset: const Offset(1, 1),
          blurRadius: 2,
        ),
      ],
    );
  }

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'position': {'x': position.dx, 'y': position.dy},
      'scale': scale,
      'rotation': rotation,
      'color': color.value,
      'fontSize': fontSize,
      'fontWeight': fontWeight.index,
      'fontFamily': fontFamily,
      'alignment': alignment.name,
      'opacity': opacity,
      'googleFontStyle': googleFontStyle?.toString(),
      'id': id,
      'isSelected': isSelected,
    };
  }

  /// Create from JSON
  factory TextElement.fromJson(Map<String, dynamic> json) {
    final position =
        SafeDataExtractor.extractPosition(json['position']);

    // Parse alignment
    final alignmentName = SafeDataExtractor.extractString(
            json['alignment'], 'alignment') ??
        'center';
    TextAlignment alignment = TextAlignment.center;
    try {
      alignment = TextAlignment.values
          .firstWhere((e) => e.name == alignmentName);
    } catch (e) {
      alignment = TextAlignment.center; // fallback
    }

    return TextElement(
      text: SafeDataExtractor.extractString(
              json['text'], 'text') ??
          '',
      position: Offset(position['x']!, position['y']!),
      scale: SafeDataExtractor.extractDouble(
              json['scale'], 'scale') ??
          1.0,
      rotation: SafeDataExtractor.extractDouble(
              json['rotation'], 'rotation') ??
          0.0,
      color: Color(SafeDataExtractor.extractInt(
              json['color'], 'color') ??
          0xFF000000),
      fontSize: SafeDataExtractor.extractDouble(
              json['fontSize'], 'fontSize') ??
          24.0,
      fontWeight: FontWeight.values[
          SafeDataExtractor.extractInt(
                  json['fontWeight'], 'fontWeight') ??
              0],
      fontFamily: SafeDataExtractor.extractString(
          json['fontFamily'], 'fontFamily'),
      alignment: alignment,
      opacity: SafeDataExtractor.extractDouble(
              json['opacity'], 'opacity') ??
          1.0,
      id: SafeDataExtractor.extractString(
              json['id'], 'id') ??
          '',
      isSelected: SafeDataExtractor.extractString(
              json['isSelected'], 'isSelected') ==
          'true',
    );
  }

  @override
  String toString() {
    return 'TextElement(id: $id, text: "$text", position: $position, selected: $isSelected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextElement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
