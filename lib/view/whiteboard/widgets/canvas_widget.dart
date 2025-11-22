import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/whiteboard_models/drawing_objects.dart';
import 'package:white_boarding_app/models/whiteboard_models/ui_state.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';
import 'package:white_boarding_app/view/whiteboard/white_board_screen.dart';
import 'package:white_boarding_app/viewmodels/active_board_viewmodel.dart';
import '../../../viewmodels/tool_viewmodel.dart';

class CanvasWidget extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  const CanvasWidget({super.key, required this.whiteBoard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialBoard = (context.findAncestorWidgetOfExactType<WhiteBoardScreen>() as WhiteBoardScreen).whiteBoard;
    final activeTool = ref.watch(toolStateProvider);
    final history = ref.watch(activeBoardHistoryProvider(initialBoard));
    final activeBoard = history.currentBoard;
    final activeBoardNotifier = ref.read(activeBoardHistoryProvider(initialBoard).notifier);
    final selectedIds = ref.watch(selectedObjectIdsProvider(initialBoard));
    final selectionMode = ref.watch(selectionModeProvider);
    final isShiftOrCtrl = ref.watch(isShiftControlPressedProvider);
    final toolOptions = ref.watch(toolOptionsProvider);
    final currentDrawingObject = ref.watch(currentDrawingObjectProvider);

    
    final FocusNode focusNode = FocusNode(debugLabel: 'Canvas Focus');

    void handleKeyEvent(RawKeyEvent event) {
      // ... (Key handling logic remains the same) ...
      if (event is RawKeyDownEvent) {
        final isMetaOrCtrl = event.isMetaPressed || event.isControlPressed;
        final isShift = event.isShiftPressed;

        if (isMetaOrCtrl || isShift) {
          ref.read(isShiftControlPressedProvider.notifier).state = true;
        }

        if (isMetaOrCtrl) {
          if (event.logicalKey == LogicalKeyboardKey.keyA) {
            final allObjectIds = activeBoard
                .slides[activeBoard.currentSlideIndex]
                .objects
                .where((obj) {
                  if (obj is PenObject && obj.isEraser) {
                    return false;
                  }
                  return true;
                })
                .map((obj) => obj.id)
                .toSet()
                .cast<String>();
            ref.read(selectedObjectIdsProvider(initialBoard).notifier).state =
                allObjectIds;
          } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
            activeBoardNotifier.duplicateSelectedObjects(initialBoard);
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) {
          activeBoardNotifier.deleteSelectedObjects(initialBoard);
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          ref.read(selectedObjectIdsProvider(initialBoard).notifier).state = {};
          ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
        }
      } else if (event is RawKeyUpEvent) {
        final isMetaOrCtrl = event.isMetaPressed || event.isControlPressed;
        final isShift = event.isShiftPressed;
        if (!isMetaOrCtrl && !isShift) {
          ref.read(isShiftControlPressedProvider.notifier).state = false;
        }
      }
    }

    void handlePanStart(Offset position) {
      if ([
        ToolType.pencil,
        ToolType.rectangle,
        ToolType.circle,
        ToolType.line,
        ToolType.arrow,
        ToolType.eraser,
      ].contains(activeTool)) {
        activeBoardNotifier.startDrawing(position, toolOptions, activeTool);
      } else if (activeTool == ToolType.selection) {
        // FIX 2: Check if we are already in a moving state from onTapDown
        // OR if we simply have items selected.
        final hasSelection = ref.read(selectedObjectIdsProvider(initialBoard)).isNotEmpty;
        final currentMode = ref.read(selectionModeProvider);

        if (currentMode != SelectionMode.none) {
          // onTapDown successfully set the mode, just update the pan start
          activeBoardNotifier.startPan(position);
        } else if (hasSelection) {
          // We have items selected, but mode is none.
          // This handles cases where onTapDown might have missed slightly but we want to drag.
          // However, strict logic: try to hit test again.
          activeBoardNotifier.selectObjectAt(position, initialBoard, isShiftOrCtrl);
          // If that set the mode, sync the pan start
           if (ref.read(selectionModeProvider) != SelectionMode.none) {
             activeBoardNotifier.startPan(position);
           }
        } else {
          // Nothing selected, try to select
          activeBoardNotifier.selectObjectAt(position, initialBoard, isShiftOrCtrl);
        }
      } else if (activeTool == ToolType.pan) {
        activeBoardNotifier.startPan(position);
      }
    }

    void handlePanUpdate(Offset position) {
      if (currentDrawingObject != null) {
        activeBoardNotifier.updateDrawing(position);
      } else if (activeTool == ToolType.eraser) {
        activeBoardNotifier.updateDrawing(position);
      } else if (activeTool == ToolType.selection &&
          // FIX 3: Use ref.read to get the fresh state during high-frequency drag events
          ref.read(selectionModeProvider) != SelectionMode.none) {
        activeBoardNotifier.updateSelectionInteraction(position);
      } else if (activeTool == ToolType.pan) {
        activeBoardNotifier.updatePan(position);
      }
    }

    void handlePanEnd(DragEndDetails details) {
      if (currentDrawingObject != null) {
        activeBoardNotifier.endDrawing();
      } else if (activeTool == ToolType.selection &&
          ref.read(selectionModeProvider) != SelectionMode.none) {
        activeBoardNotifier.commitSelectionInteraction();
      } else if (activeTool == ToolType.pan) {
        activeBoardNotifier.endPan();
      }
    }

    void handleDoubleTap(Offset position) {
      if (activeTool == ToolType.text) {
        debugPrint("Text input triggered at $position");
      }
    }

    return RawKeyboardListener(
      focusNode: focusNode,
      onKey: handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
       
          return Padding(
            padding: const EdgeInsets.all(10),
            child: GestureDetector(
              onPanStart: (details) {
                focusNode.requestFocus();
                handlePanStart(details.localPosition);
              },
              onPanUpdate: (details) {
                final clampedPos = Offset(
                  details.localPosition.dx.clamp(0.0, constraints.maxWidth),
                  details.localPosition.dy.clamp(0.0, constraints.maxHeight),
                );
                handlePanUpdate(clampedPos);
              },
              onPanEnd: handlePanEnd,
              onTapDown: (details) {
                if (activeTool == ToolType.selection) {
                  activeBoardNotifier.selectObjectAt(
                    details.localPosition,
                    initialBoard,
                    isShiftOrCtrl,
                  );
                }
              },
              onDoubleTapDown: (details) => handleDoubleTap(details.localPosition),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: ClipRect(
                  child: CustomPaint(
                    painter: WhiteBoardPainter(
                      whiteBoard: activeBoard,
                      currentDrawingObject: currentDrawingObject,
                      selectedObjectIds: selectedIds,
                      selectionMode: selectionMode,
                      activeBoardNotifier: activeBoardNotifier,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
class WhiteBoardPainter extends CustomPainter {
  final WhiteBoard whiteBoard;
  final dynamic currentDrawingObject;
  final Set<String> selectedObjectIds;
  final SelectionMode selectionMode;
  final ActiveBoardNotifier activeBoardNotifier;

  WhiteBoardPainter({
    required this.whiteBoard,
    this.currentDrawingObject,
    required this.selectedObjectIds,
    required this.selectionMode,
    required this.activeBoardNotifier,
  });

  Rect _getBounds(dynamic object) => activeBoardNotifier.getBounds(object);

  Color _colorFromHex(String hexColor, double opacity) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    int hex = int.parse(hexColor, radix: 16);
    Color color = Color(hex);
    return color.withOpacity(color.opacity * opacity);
  }

  Paint _getPenPaint(PenObject object) {
    return Paint()
      ..color = _colorFromHex(object.color, object.opacity)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = object.strokeWidth
      ..style = PaintingStyle.stroke;
  }

  void _drawPenObject(Canvas canvas, PenObject object) {
    final paint = _getPenPaint(object);

    if (object.points.isEmpty) return;

    if (object.points.length == 1) {
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(object.points.first.x, object.points.first.y),
        object.strokeWidth / 2,
        paint,
      );
    } else {
      final path = Path();
      path.moveTo(object.points.first.x, object.points.first.y);
      for (int i = 1; i < object.points.length; i++) {
        path.lineTo(object.points[i].x, object.points[i].y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawDrawingObject(Canvas canvas, DrawingObject object) {
    final attr = object.attributes;

    final strokePaint = Paint()
      ..color = _colorFromHex(attr.strokeColor, attr.opacity)
      ..strokeWidth = attr.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = _colorFromHex(attr.fillColor, attr.opacity)
      ..style = PaintingStyle.fill;

    final rect = _getBounds(object);

    if (object.type == 'rectangle') {
      if (attr.fillColor != '#FFFFFF' && attr.fillColor != '#FFFFFFFF') {
        canvas.drawRect(rect, fillPaint);
      }
      canvas.drawRect(rect, strokePaint);
    } else if (object.type == 'circle') {
      final center = rect.center;
      final radius = math.min(rect.width, rect.height) / 2;

      if (attr.fillColor != '#FFFFFF' && attr.fillColor != '#FFFFFFFF') {
        canvas.drawCircle(center, radius, fillPaint);
      }
      canvas.drawCircle(center, radius, strokePaint);
    } else if (object.type == 'line' || object.type == 'arrow') {
      final start = Offset(attr.x, attr.y);
      final end = Offset(attr.x + attr.width, attr.y + attr.height);

      canvas.drawLine(start, end, strokePaint);

      if (object.type == 'arrow') {
        _drawArrowhead(canvas, start, end, strokePaint);
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double arrowLength = 15;
    const double arrowAngle = math.pi / 6;

    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final path = Path();

    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowLength * math.cos(angle - arrowAngle),
      end.dy - arrowLength * math.sin(angle - arrowAngle),
    );
    path.moveTo(end.dx, end.dy);
    path.lineTo(
      end.dx - arrowLength * math.cos(angle + arrowAngle),
      end.dy - arrowLength * math.sin(angle + arrowAngle),
    );

    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  void _drawSelectionBox(Canvas canvas, Rect bounds, dynamic object) {
    const double handleSize = 12.0;

    final borderPaint = Paint()
      ..color = const Color(0xFF55B8B9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 4.0;

    final inflatedBounds = bounds.inflate(4);

    Path dashPath = Path();

    void drawDashedLine(Offset p1, Offset p2) {
      final distance = (p2 - p1).distance;
      final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      for (double i = 0; i < distance; i += dashWidth + dashSpace) {
        final startX = p1.dx + math.cos(angle) * i;
        final startY = p1.dy + math.sin(angle) * i;
        final endX = p1.dx + math.cos(angle) * (i + dashWidth);
        final endY = p1.dy + math.sin(angle) * (i + dashWidth);

        dashPath.moveTo(startX, startY);
        dashPath.lineTo(endX, endY);
      }
    }

    drawDashedLine(inflatedBounds.topLeft, inflatedBounds.topRight);
    drawDashedLine(inflatedBounds.topRight, inflatedBounds.bottomRight);
    drawDashedLine(inflatedBounds.bottomRight, inflatedBounds.bottomLeft);
    drawDashedLine(inflatedBounds.bottomLeft, inflatedBounds.topLeft);

    canvas.drawPath(dashPath, borderPaint);

    if (object is DrawingObject) {
      final handlePaint = Paint()
        ..color = const Color(0xFF55B8B9)
        ..style = PaintingStyle.fill;

      final handleBorderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final handles = [
        inflatedBounds.topLeft,
        inflatedBounds.topRight,
        inflatedBounds.bottomLeft,
        inflatedBounds.bottomRight,
      ];

      for (var center in handles) {
        canvas.drawCircle(center, handleSize / 2, handlePaint);
        canvas.drawCircle(center, handleSize / 2, handleBorderPaint);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final currentSlide = whiteBoard.slides[whiteBoard.currentSlideIndex];
    List<dynamic> objectsToDrawSelection = [];

    for (var object in currentSlide.objects) {
      if (object is PenObject) {
        _drawPenObject(canvas, object);
      } else if (object is DrawingObject) {
        _drawDrawingObject(canvas, object);
      }

      if (selectedObjectIds.contains(object.id)) {
        objectsToDrawSelection.add(object);
      }
    }

    if (currentDrawingObject != null) {
      if (currentDrawingObject is PenObject) {
        _drawPenObject(canvas, currentDrawingObject!);
      } else if (currentDrawingObject is DrawingObject) {
        _drawDrawingObject(canvas, currentDrawingObject!);
      }
    }

    for (var object in objectsToDrawSelection) {
      final bounds = _getBounds(object);
      _drawSelectionBox(canvas, bounds, object);
    }
  }

  @override
  bool shouldRepaint(covariant WhiteBoardPainter oldDelegate) {
    final objectsChanged =
        oldDelegate
                .whiteBoard
                .slides[oldDelegate.whiteBoard.currentSlideIndex]
                .objects !=
            whiteBoard.slides[whiteBoard.currentSlideIndex].objects;

    final currentDrawingChanged =
        oldDelegate.currentDrawingObject != currentDrawingObject;

    final selectionChanged =
        oldDelegate.selectedObjectIds != selectedObjectIds ||
        oldDelegate.selectionMode != selectionMode;

    return objectsChanged || currentDrawingChanged || selectionChanged;
  }
}