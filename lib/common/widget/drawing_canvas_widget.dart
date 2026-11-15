import 'package:flutter/material.dart';
import 'package:toptap/model/drawing/draw_stroke.dart';

/// Custom painter for drawing strokes on canvas
class DrawingPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  final DrawStroke? currentStroke;

  DrawingPainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Use saveLayer for proper blend mode support (especially for eraser)
    canvas.saveLayer(Offset.zero & size, Paint());

    // Draw all completed strokes
    for (var stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw current stroke being drawn
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, DrawStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color.withOpacity(stroke.opacity)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // If eraser, use destination out blend mode (removes what's underneath)
    if (stroke.isEraser) {
      paint.blendMode = BlendMode.dstOut;
      paint.color =
          Colors.white; // Color doesn't matter for dstOut
    }

    // Draw path connecting all points
    if (stroke.points.length == 1) {
      // Single point - draw a dot
      canvas.drawCircle(
          stroke.points[0], stroke.strokeWidth / 2, paint);
    } else {
      // Multiple points - draw path
      final path = Path();
      path.moveTo(stroke.points[0].dx, stroke.points[0].dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final p1 = stroke.points[i - 1];
        final p2 = stroke.points[i];

        // Use quadratic bezier for smoother curves
        final midPoint = Offset(
          (p1.dx + p2.dx) / 2,
          (p1.dy + p2.dy) / 2,
        );

        if (i == 1) {
          path.lineTo(midPoint.dx, midPoint.dy);
        } else {
          path.quadraticBezierTo(
            p1.dx,
            p1.dy,
            midPoint.dx,
            midPoint.dy,
          );
        }
      }

      // Draw the last segment
      final lastPoint = stroke.points.last;
      path.lineTo(lastPoint.dx, lastPoint.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke;
  }
}

/// Drawing canvas widget with gesture detection
class DrawingCanvas extends StatefulWidget {
  final List<DrawStroke> strokes;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
  final bool isActive; // Whether drawing mode is active
  final Function(DrawStroke) onStrokeCompleted;
  final Function(Offset)? onDrawStart;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    required this.isEraser,
    this.isActive = true,
    required this.onStrokeCompleted,
    this.onDrawStart,
  });

  @override
  State<DrawingCanvas> createState() =>
      _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  DrawStroke? _currentStroke;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: widget.isActive ? _handlePanStart : null,
      onPanUpdate:
          widget.isActive ? _handlePanUpdate : null,
      onPanEnd: widget.isActive ? _handlePanEnd : null,
      child: CustomPaint(
        painter: DrawingPainter(
          strokes: widget.strokes,
          currentStroke: _currentStroke,
        ),
        size: Size.infinite,
        child: Container(
            color: Colors
                .transparent), // Transparent for hit testing
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    widget.onDrawStart?.call(details.localPosition);

    setState(() {
      _currentStroke = DrawStroke(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
        points: [details.localPosition],
        color: widget.color,
        strokeWidth: widget.strokeWidth,
        isEraser: widget.isEraser,
      );
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;

    setState(() {
      _currentStroke =
          _currentStroke!.addPoint(details.localPosition);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_currentStroke != null &&
        _currentStroke!.points.isNotEmpty) {
      widget.onStrokeCompleted(_currentStroke!);
    }
    setState(() {
      _currentStroke = null;
    });
  }
}
