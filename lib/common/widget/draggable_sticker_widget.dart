import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:toptap/model/sticker/positioned_sticker.dart';

class DraggableStickerWidget extends StatefulWidget {
  final PositionedSticker positionedSticker;
  final VoidCallback onDelete;
  final Function(PositionedSticker) onUpdate;
  final bool isSelected;
  final VoidCallback onTap;
  final bool
      hideControls; // Hide border and delete button for screenshots

  const DraggableStickerWidget({
    super.key,
    required this.positionedSticker,
    required this.onDelete,
    required this.onUpdate,
    required this.isSelected,
    required this.onTap,
    this.hideControls =
        false, // Default: show controls during editing
  });

  @override
  State<DraggableStickerWidget> createState() =>
      _DraggableStickerWidgetState();
}

class _DraggableStickerWidgetState
    extends State<DraggableStickerWidget> {
  late PositionedSticker _sticker;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _sticker = widget.positionedSticker;
  }

  @override
  void didUpdateWidget(DraggableStickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionedSticker !=
        widget.positionedSticker) {
      _sticker = widget.positionedSticker;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _sticker.x,
      top: _sticker.y,
      child: GestureDetector(
        onTap: widget.onTap,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: (_) {},
        child: Transform.rotate(
          angle: _sticker.rotation,
          child: Container(
            width: _sticker.width * _sticker.scale,
            height: _sticker.height * _sticker.scale,
            decoration: BoxDecoration(
              border:
                  widget.isSelected && !widget.hideControls
                      ? Border.all(
                          color: Colors.white, width: 2)
                      : null,
            ),
            child: Stack(
              children: [
                // Sticker image
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: _sticker.sticker.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image),
                  ),
                ),

                // Delete button (only when selected and controls visible)
                if (widget.isSelected &&
                    !widget.hideControls)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white,
                              width: 2),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _sticker.scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Handle dragging (when one finger)
      if (details.scale == 1.0) {
        _sticker.x += details.focalPointDelta.dx;
        _sticker.y += details.focalPointDelta.dy;
      } else {
        // Handle scaling and rotation (when two fingers)
        _sticker.rotation += details.rotation;

        double newScale = _baseScale * details.scale;
        newScale =
            newScale.clamp(0.5, 3.0); // Min 0.5x, Max 3x
        _sticker.scale = newScale;
      }
    });
    widget.onUpdate(_sticker);
  }
}
