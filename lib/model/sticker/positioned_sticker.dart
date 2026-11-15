import 'package:toptap/model/sticker/sticker_model.dart';

/// Model for a positioned sticker on the canvas
class PositionedSticker {
  final String id;
  final StickerModel sticker;
  double x;
  double y;
  double width;
  double height;
  double rotation;
  double scale;

  PositionedSticker({
    required this.id,
    required this.sticker,
    this.x = 0,
    this.y = 0,
    this.width = 150,
    this.height = 150,
    this.rotation = 0,
    this.scale = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sticker': sticker.toJson(),
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'scale': scale,
      };

  factory PositionedSticker.fromJson(
          Map<String, dynamic> json) =>
      PositionedSticker(
        id: json['id'] ?? '',
        sticker:
            StickerModel.fromJson(json['sticker'] ?? {}),
        x: json['x']?.toDouble() ?? 0,
        y: json['y']?.toDouble() ?? 0,
        width: json['width']?.toDouble() ?? 150,
        height: json['height']?.toDouble() ?? 150,
        rotation: json['rotation']?.toDouble() ?? 0,
        scale: json['scale']?.toDouble() ?? 1.0,
      );

  PositionedSticker copyWith({
    String? id,
    StickerModel? sticker,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? scale,
  }) {
    return PositionedSticker(
      id: id ?? this.id,
      sticker: sticker ?? this.sticker,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }
}
