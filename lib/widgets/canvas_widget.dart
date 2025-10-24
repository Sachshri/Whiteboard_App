import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for keyboard listener
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/drawing_objects.dart';
import 'package:white_boarding_app/models/ui_state.dart';
import 'package:white_boarding_app/view/white_board_screen.dart';
import 'package:white_boarding_app/viewmodels/active_board_viewmodel.dart';
import '../models/white_board.dart';
import '../viewmodels/tool_viewmodel.dart';

class CanvasWidget extends ConsumerWidget {
  final WhiteBoard whiteBoard;
  const CanvasWidget({super.key, required this.whiteBoard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We use the initialBoard passed to the screen as the family key
    final initialBoard =
        (context.findAncestorWidgetOfExactType<WhiteBoardScreen>()
                as WhiteBoardScreen)
            .whiteBoard;
    final activeTool = ref.watch(toolStateProvider);
    final history = ref.watch(activeBoardHistoryProvider(initialBoard));
    final activeBoard = history.currentBoard;
    final activeBoardNotifier = ref.read(
      activeBoardHistoryProvider(initialBoard).notifier,
    );
    final selectedIds = ref.watch(selectedObjectIdsProvider(initialBoard));
    final selectionMode = ref.watch(selectionModeProvider);
    final isShiftOrCtrl = ref.watch(isShiftControlPressedProvider); // NEW: Watch key state

    final toolOptions = ref.watch(toolOptionsProvider);

    // Watch the temporary object (now dynamic)
    final currentDrawingObject = ref.watch(currentDrawingObjectProvider);

    // Focus node to listen to keyboard events (for desktop/web)
    final FocusNode focusNode = FocusNode(debugLabel: 'Canvas Focus');
    
    // Listen for Ctrl+A (Select All) and Delete/Backspace
    void handleKeyEvent(RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          final isMetaOrCtrl = event.isMetaPressed || event.isControlPressed;
          final isShift = event.isShiftPressed;

          // NEW: Update isShiftControlPressedProvider (for UI feedback, and selection logic)
          if (isMetaOrCtrl || isShift) {
             ref.read(isShiftControlPressedProvider.notifier).state = true;
          }

          if (isMetaOrCtrl) {
            if (event.logicalKey == LogicalKeyboardKey.keyA) {
              // Ctrl+A: Select all
              final allObjectIds = activeBoard.slides[activeBoard.currentSlideIndex].objects
                  .map((obj) => obj.id)
                  .toSet().cast<String>();
              ref.read(selectedObjectIdsProvider(initialBoard).notifier).state = allObjectIds;
            } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
              // Ctrl+V: Duplicate (trigger duplicate logic)
              activeBoardNotifier.duplicateSelectedObjects(initialBoard);
            }
          }
          
          if (event.logicalKey == LogicalKeyboardKey.delete || 
              event.logicalKey == LogicalKeyboardKey.backspace) {
            // Delete: Remove selected objects
            activeBoardNotifier.deleteSelectedObjects(initialBoard);
          }
           if (event.logicalKey == LogicalKeyboardKey.escape) {
            // Esc: Deselect
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
      ].contains(activeTool)) {
        // Start drawing for creation tools
        activeBoardNotifier.startDrawing(position, toolOptions, activeTool);
      } else if (activeTool == ToolType.selection) {
        // NEW: Start selection or manipulation, passing the key state
        activeBoardNotifier.selectObjectAt(position, initialBoard, isShiftOrCtrl); 
      } else if (activeTool == ToolType.pan) {
        // TODO: Implement pan start logic
        debugPrint("Pan started at $position");
      }
    }

    void handlePanUpdate(Offset position) {
      if (currentDrawingObject != null) {
        activeBoardNotifier.updateDrawing(position);
      } else if (activeTool == ToolType.selection && selectionMode != SelectionMode.none) {
        // NEW: Move or resize the selected object(s)
        activeBoardNotifier.updateSelectionInteraction(position);
      } else if (activeTool == ToolType.pan) {
        // TODO: Implement pan update logic (move the canvas view/objects)
      }
    }

    void handlePanEnd(DragEndDetails details) {
      if (currentDrawingObject != null) {
        activeBoardNotifier.endDrawing();
      } else if (activeTool == ToolType.selection && selectionMode != SelectionMode.none) {
        // NEW: Commit move or resize to history
        activeBoardNotifier.commitSelectionInteraction();
      } else if (activeTool == ToolType.pan) {
        // TODO: Implement pan end logic
      }
    }

    // Note: Added a double-tap handler to stub text creation for future use
    void handleDoubleTap(Offset position) {
      if (activeTool == ToolType.text) {
        debugPrint("Text input triggered at $position");
        // TODO: Show a text input box at this position and add a text object on confirmation
      }
    }

    return RawKeyboardListener(
      focusNode: focusNode,
      onKey: handleKeyEvent,
      child: GestureDetector(
        onPanStart: (details) {
          // Request focus on interaction start for keyboard listeners to work
          focusNode.requestFocus(); 
          handlePanStart(details.localPosition);
        },
        onPanUpdate: (details) => handlePanUpdate(details.localPosition),
        onPanEnd: handlePanEnd,
        onTapDown: (details) {
          // Handle tap-down when not dragging (for immediate deselect or single select)
          if (activeTool == ToolType.selection) {
            // Re-run selectObjectAt here to handle single tap deselect logic
            activeBoardNotifier.selectObjectAt(details.localPosition, initialBoard, isShiftOrCtrl);
          }
        },
        onDoubleTapDown: (details) => handleDoubleTap(details.localPosition),
        child: Container(
          // This container acts as the white grid/pattern area of the whiteboard
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: CustomPaint(
            // Pass the current active object and selected IDs for visual feedback
            painter: WhiteBoardPainter(
              whiteBoard: activeBoard,
              currentDrawingObject: currentDrawingObject,
              selectedObjectIds: selectedIds,
              selectionMode: selectionMode, // NEW
              activeBoardNotifier: activeBoardNotifier, // NEW
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class WhiteBoardPainter extends CustomPainter {
  final WhiteBoard whiteBoard;
  final dynamic currentDrawingObject; // The object being actively drawn
  final Set<String> selectedObjectIds; // IDs of currently selected objects
  final SelectionMode selectionMode; // NEW: Current mode for cursor feedback
  final ActiveBoardNotifier activeBoardNotifier; // NEW: Access to bounds utility

  WhiteBoardPainter({
    required this.whiteBoard,
    this.currentDrawingObject,
    required this.selectedObjectIds,
    required this.selectionMode,
    required this.activeBoardNotifier,
  });

  // Utility to get the Rect bounding box (from ActiveBoardNotifier)
  Rect _getBounds(dynamic object) => activeBoardNotifier.getBounds(object);
  
  // Utility to convert hex string to Color
  Color _colorFromHex(String hexColor, double opacity) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    // Ensure opacity is applied correctly on top of any alpha in the hex string
    int hex = int.parse(hexColor, radix: 16);
    Color color = Color(hex);
    return color.withOpacity(color.opacity * opacity);
  }

  // Utility to create a Paint object for a PenObject
  Paint _getPenPaint(PenObject object) {
    return Paint()
      ..color = _colorFromHex(object.color, object.opacity)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = object.strokeWidth
      ..style = PaintingStyle.stroke;
  }

  // Utility to draw a PenObject (Path)
  void _drawPenObject(Canvas canvas, PenObject object) {
    final paint = _getPenPaint(object);
    final path = Path();

    if (object.points.isNotEmpty) {
      path.moveTo(object.points.first.x, object.points.first.y);
      for (int i = 1; i < object.points.length; i++) {
        path.lineTo(object.points[i].x, object.points[i].y);
      }
    }
    canvas.drawPath(path, paint);
  }

  // Utility to draw generic DrawingObjects (shapes)
  void _drawDrawingObject(Canvas canvas, DrawingObject object) {
    final attr = object.attributes;

    // Stroke Paint
    final strokePaint = Paint()
      ..color = _colorFromHex(attr.strokeColor, attr.opacity)
      ..strokeWidth = attr.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Fill Paint (Fill color uses a distinct paint to handle opacity layering)
    final fillPaint = Paint()
      ..color = _colorFromHex(attr.fillColor, attr.opacity)
      ..style = PaintingStyle.fill;

    // Calculate normalized rect from attributes (already handled by _getBounds logic)
    final rect = _getBounds(object);

    if (object.type == 'rectangle') {
      if (attr.fillColor != '#FFFFFF' && attr.fillColor != '#FFFFFFFF') {
        canvas.drawRect(rect, fillPaint);
      }
      canvas.drawRect(rect, strokePaint);
    } else if (object.type == 'circle') {
      // Draw a circle (or ellipse) centered within the defined rect
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
    // TODO: Add logic for 'text', 'image' here
  }

  // Utility to draw an arrowhead at the end of a line
  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double arrowLength = 15;
    const double arrowAngle = math.pi / 6; // 30 degrees

    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final path = Path();

    // Calculate points for the two sides of the arrowhead
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

    // Use fill paint or stroke paint with a large stroke width for a solid look
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  // NEW: Draw selection box and handles
  void _drawSelectionBox(Canvas canvas, Rect bounds, dynamic object) {
    const double handleSize = 12.0;
    
    // Draw dashed border
    final borderPaint = Paint()
      ..color = const Color(0xFF55B8B9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    
    // Use an inflated rect for a slight border offset (this is where the handles sit)
    final inflatedBounds = bounds.inflate(4);
    
    // Draw dashed path (simplified implementation)
    Path dashPath = Path();
    
    // Line drawing utility for dashed effect
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

    // Only draw resize handles for DrawingObjects (shapes)
    // Note: PenObject can be moved, but not resized via handles in this implementation.
    if (object is DrawingObject) {
      final handlePaint = Paint()
        ..color = const Color(0xFF55B8B9)
        ..style = PaintingStyle.fill;
      
      final handleBorderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      
      // Draw corner handles on the inflated bounds
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
    
    // List to keep track of objects that need selection drawing (for drawing on top)
    List<dynamic> objectsToDrawSelection = [];

    // 1. Draw Saved Objects
    for (var object in currentSlide.objects) {
      if (object is PenObject) {
        _drawPenObject(canvas, object);
      } else if (object is DrawingObject) {
        _drawDrawingObject(canvas, object);
      }
      
      // Collect selected objects
      if (selectedObjectIds.contains(object.id)) {
        objectsToDrawSelection.add(object);
      }
    }

    // 2. Draw the actively drawn object (real-time feedback for creation tools)
    if (currentDrawingObject != null) {
      if (currentDrawingObject is PenObject) {
        _drawPenObject(canvas, currentDrawingObject!);
      } else if (currentDrawingObject is DrawingObject) {
        _drawDrawingObject(canvas, currentDrawingObject!);
      }
    }
    
    // 3. Draw Selection Boxes (drawn last to overlay objects)
    for (var object in objectsToDrawSelection) {
      final bounds = _getBounds(object);
      _drawSelectionBox(canvas, bounds, object);
    }
  }

  @override
  bool shouldRepaint(covariant WhiteBoardPainter oldDelegate) {
    // Repaint if objects change OR the temporary object changes OR the selection changes
    final objectsChanged =
        oldDelegate
            .whiteBoard
            .slides[oldDelegate.whiteBoard.currentSlideIndex]
            .objects !=
        whiteBoard.slides[whiteBoard.currentSlideIndex].objects;

    final currentDrawingChanged =
        oldDelegate.currentDrawingObject != currentDrawingObject;
        
    final selectionChanged = oldDelegate.selectedObjectIds != selectedObjectIds || oldDelegate.selectionMode != selectionMode;

    return objectsChanged || currentDrawingChanged || selectionChanged;
  }
}