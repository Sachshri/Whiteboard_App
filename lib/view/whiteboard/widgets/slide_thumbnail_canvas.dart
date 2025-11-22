import 'dart:math' as math show min;
import 'package:flutter/material.dart';
import 'package:white_boarding_app/models/whiteboard_models/drawing_objects.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';

class SlideThumbnailCanvas extends StatelessWidget {
  final Slide slide;
  final double width;
  final double height;

  static const double originalCanvasWidth = 1000.0;
  static const double originalCanvasHeight = 800.0;

  const SlideThumbnailCanvas({
    super.key,
    required this.slide,
    this.width = 160,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      // FIX: Clip the painting to the container's bounds + rounded corners
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(painter: SlideThumbnailPainter(slide: slide)),
      ),
    );
  }
}

class SlideThumbnailPainter extends CustomPainter {
  final Slide slide;

  SlideThumbnailPainter({required this.slide});

  Color _colorFromHex(String hexColor, double opacity) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }

    int hex = int.parse(hexColor, radix: 16);
    Color color = Color(hex);
    return color.withOpacity(color.opacity * opacity);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / SlideThumbnailCanvas.originalCanvasWidth;
    final scaleY = size.height / SlideThumbnailCanvas.originalCanvasHeight;
    final scaleFactor = math.min(scaleX, scaleY);

    canvas.scale(scaleFactor);

    for (var object in slide.objects) {
      if (object is DrawingObject) {
        final attr = object.attributes;
        final paint = Paint()
          ..strokeWidth = attr.strokeWidth / scaleFactor
          ..strokeCap = StrokeCap.round
          ..color = _colorFromHex(attr.strokeColor, attr.opacity)
          ..style = PaintingStyle.stroke;

        final rect = Rect.fromLTWH(attr.x, attr.y, attr.width, attr.height);

        if (object.type == 'rectangle') {
          if (attr.fillColor != '#FFFFFF' && attr.fillColor != '#FFFFFFFF') {
            final fillPaint = Paint()
              ..color = _colorFromHex(attr.fillColor, attr.opacity)
              ..style = PaintingStyle.fill;
            canvas.drawRect(rect, fillPaint);
          }
          canvas.drawRect(rect, paint);
        } else if (object.type == 'circle') {
          final center = rect.center;
          final radius = math.min(attr.width.abs(), attr.height.abs()) / 2;
          if (attr.fillColor != '#FFFFFF' && attr.fillColor != '#FFFFFFFF') {
            final fillPaint = Paint()
              ..color = _colorFromHex(attr.fillColor, attr.opacity)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(center, radius, fillPaint);
          }
          canvas.drawCircle(center, radius, paint);
        } else if (object.type == 'line' || object.type == 'arrow') {
          canvas.drawLine(
            Offset(attr.x, attr.y),
            Offset(attr.x + attr.width, attr.y + attr.height),
            paint,
          );
        }
      } else if (object is PenObject) {
        final path = Path();
        final paint = Paint()
          ..color = _colorFromHex(object.color, object.opacity)
          ..strokeWidth = object.strokeWidth / scaleFactor
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        if (object.points.isNotEmpty) {
          path.moveTo(object.points.first.x, object.points.first.y);
          for (int i = 1; i < object.points.length; i++) {
            path.lineTo(object.points[i].x, object.points[i].y);
          }
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(SlideThumbnailPainter oldDelegate) {
    return oldDelegate.slide.objects != slide.objects;
  }
}