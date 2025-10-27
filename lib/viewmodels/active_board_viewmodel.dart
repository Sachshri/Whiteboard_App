import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:white_boarding_app/viewmodels/tool_viewmodel.dart';
import '../models/drawing_objects.dart';
import '../models/ui_state.dart';
import '../models/white_board.dart';
import '../models/white_board_history.dart';
import 'white_board_viewmodel.dart';
import 'dart:math' as math; // Import math for boundary calculations

// Provides the WhiteBoardHistory state for the active board
final activeBoardHistoryProvider =
    StateNotifierProvider.family<
      ActiveBoardNotifier,
      WhiteBoardHistory,
      WhiteBoard
    >((ref, initialBoard) {
      return ActiveBoardNotifier(initialBoard, ref);
    });
// Provides the temporary object being drawn in real-time
final currentDrawingObjectProvider = StateProvider<dynamic>((ref) => null);

// Tracks IDs of selected objects (supports multi-selection)
final selectedObjectIdsProvider = StateProvider.family<Set<String>, WhiteBoard>(
  (ref, initialBoard) => {},
);

// Tracks the current interaction mode when selection tool is active
final selectionModeProvider = StateProvider.autoDispose<SelectionMode>(
  (ref) => SelectionMode.none,
);

// Stores the position offset for drag/move operations (used for selection interaction)
final dragOffsetProvider = StateProvider<Offset?>((ref) => null);
final isShiftControlPressedProvider = StateProvider<bool>((ref) => false);

class ActiveBoardNotifier extends StateNotifier<WhiteBoardHistory> {
  final Ref _ref;
  final Uuid _uuid = const Uuid();
  Offset?
  _startPosition; // Used for drawing shapes and selection interaction start point
  final Set<String> _objectsErasedInThisStroke = {};

  ActiveBoardNotifier(WhiteBoard initialBoard, this._ref)
    : super(WhiteBoardHistory.initial(initialBoard));

  WhiteBoard get _currentBoard => state.currentBoard;
  Slide get _currentSlide =>
      _currentBoard.slides[_currentBoard.currentSlideIndex];

  // --- HISTORY MANAGEMENT ---

  void pushNewState(WhiteBoard newState) {
    state = state.push(newState);
    // Update the global list to persist changes
    _ref.read(whiteBoardListProvider.notifier).updateWhiteBoard(newState);
    // Selection state remains local but should reference objects in the current board state
  }

  void undo() {
    state = state.undo();
    _ref.read(whiteBoardListProvider.notifier).updateWhiteBoard(_currentBoard);
  }

  void redo() {
    state = state.redo();
    _ref.read(whiteBoardListProvider.notifier).updateWhiteBoard(_currentBoard);
  }

  // --- SLIDE MANAGEMENT (Omitted for brevity, assumed correct) ---
  void changeSlide(int newIndex) {
    final newBoard = _currentBoard.copyWith(currentSlideIndex: newIndex);
    pushNewState(newBoard);
    // Clear selection when changing slides
    _ref.read(selectedObjectIdsProvider(newBoard).notifier).state = {};
  }

  void addSlide() {
    final newSlide = Slide(id: _uuid.v4());
    final List<Slide> newSlides = [..._currentBoard.slides, newSlide];
    final newBoard = _currentBoard.copyWith(
      slides: newSlides,
      currentSlideIndex: newSlides.length - 1,
    );
    pushNewState(newBoard);
  }

  void deleteSlide(int index) {
    if (_currentBoard.slides.length <= 1) return;

    final List<Slide> newSlides = List.from(_currentBoard.slides)
      ..removeAt(index);
    int newIndex = _currentBoard.currentSlideIndex;
    if (newIndex >= newSlides.length) {
      newIndex = newSlides.length - 1;
    }

    final newBoard = _currentBoard.copyWith(
      slides: newSlides,
      currentSlideIndex: newIndex,
    );
    pushNewState(newBoard);
  }

  void moveSlide(int oldIndex, int newIndex) {
    final List<Slide> newSlides = List.from(_currentBoard.slides);
    final slideToMove = newSlides.removeAt(oldIndex);
    newSlides.insert(newIndex, slideToMove);

    int newCurrentIndex = _currentBoard.currentSlideIndex;
    if (oldIndex == _currentBoard.currentSlideIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < _currentBoard.currentSlideIndex &&
        newIndex >= _currentBoard.currentSlideIndex) {
      newCurrentIndex -= 1;
    } else if (oldIndex > _currentBoard.currentSlideIndex &&
        newIndex <= _currentBoard.currentSlideIndex) {
      newCurrentIndex += 1;
    }

    final newBoard = _currentBoard.copyWith(
      slides: newSlides,
      currentSlideIndex: newCurrentIndex,
    );
    pushNewState(newBoard);
  }

  // --- DRAWING LOGIC ---
  void startDrawing(Offset position, ToolOptions options, ToolType type) {
    _startPosition = position;
    final String newId = _uuid.v4();
    if (type == ToolType.eraser) {
      if (options.eraserMode == EraserMode.pixel) {
        final EraserObject newEraser = EraserObject(
          id: newId,
          points: [PointData(x: position.dx, y: position.dy)],
          strokeWidth: options.eraserSize, // Use eraserSize
        );
        _ref.read(currentDrawingObjectProvider.notifier).state = newEraser;
      } else {
        // Stroke Mode: Clear the tracking set and erase at the start point
        _objectsErasedInThisStroke.clear();
        _eraseStrokeAt(position);
      }
      return; // Stop here
    }
    if (type == ToolType.pencil) {
      final PenObject newPen = PenObject(
        id: newId,
        points: [PointData(x: position.dx, y: position.dy)],
        strokeWidth: options.strokeWidth,
        color: options.color,
        opacity: options.opacity,
      );
      _ref.read(currentDrawingObjectProvider.notifier).state = newPen;
    } else if ([
      ToolType.rectangle,
      ToolType.circle,
      ToolType.line,
      ToolType.arrow,
    ].contains(type)) {
      final DrawingObject newShape = DrawingObject(
        id: newId,
        type: type.toString().split('.').last, // 'rectangle', 'circle', etc.
        attributes: Attributes(
          x: position.dx,
          y: position.dy,
          // width/height start at 0
          strokeWidth: options.strokeWidth,
          strokeColor: options.color,
          fillColor: options.fillColor,
          opacity: options.opacity,
        ),
      );
      _ref.read(currentDrawingObjectProvider.notifier).state = newShape;
    }
    // For selection/pan/text/image, interaction logic is different and should be handled here
  }

  void updateDrawing(Offset position) {
    final currentObject = _ref.read(currentDrawingObjectProvider);
    if (currentObject == null) return;
    if (currentObject is EraserObject) {
      final updatedPoints = List<PointData>.from(currentObject.points)
        ..add(PointData(x: position.dx, y: position.dy));
      _ref.read(currentDrawingObjectProvider.notifier).state = currentObject
          .copyWith(points: updatedPoints);
      return; // Stop here
    }
    if (currentObject is PenObject) {
      final updatedPoints = List<PointData>.from(currentObject.points)
        ..add(PointData(x: position.dx, y: position.dy));
      _ref.read(currentDrawingObjectProvider.notifier).state = currentObject
          .copyWith(points: updatedPoints);
    } else if (currentObject is DrawingObject && _startPosition != null) {
      final double newWidth = position.dx - _startPosition!.dx;
      final double newHeight = position.dy - _startPosition!.dy;

      final updatedAttributes = currentObject.attributes.copyWith(
        width: newWidth,
        height: newHeight,
      );

      _ref.read(currentDrawingObjectProvider.notifier).state = currentObject
          .copyWith(attributes: updatedAttributes);
    }
  }

  void endDrawing() {
    final currentObject = _ref.read(currentDrawingObjectProvider);
    final activeTool = _ref.read(toolStateProvider);
    final options = _ref.read(toolOptionsProvider);
    bool shouldCommit = false;
    if (activeTool == ToolType.eraser &&
        options.eraserMode == EraserMode.stroke &&
        _objectsErasedInThisStroke.isNotEmpty) {
      pushNewState(_currentBoard);
      _objectsErasedInThisStroke.clear();
      return;
    }
    if (currentObject == null) {
      _startPosition = null;
      return;
    }
    if (currentObject is PenObject && currentObject.points.isNotEmpty) // This has the same meaninig as currentObject is PenObject && currentObject.points.length >= 1
    {
      shouldCommit = true;
    } else if (currentObject is DrawingObject &&
        (currentObject.attributes.width.abs() > 2 ||
            currentObject.attributes.height.abs() > 2)) {
      shouldCommit = true;
    }else if (currentObject is EraserObject && currentObject.points.length > 1) {
      shouldCommit = true;
    }

    if (shouldCommit) {
      final List<dynamic> newObjects = List.from(_currentSlide.objects)
        ..add(currentObject);

      final newSlide = _currentSlide.copyWith(objects: newObjects);
      final newSlides = List<Slide>.from(_currentBoard.slides);
      newSlides[_currentBoard.currentSlideIndex] = newSlide;

      final newBoard = _currentBoard.copyWith(slides: newSlides);
      pushNewState(newBoard);
    }

    // Reset temporary state
    _ref.read(currentDrawingObjectProvider.notifier).state = null;
    _startPosition = null;
  }
  // --- END DRAWING LOGIC ---


  // --- NEW SELECTION & MODIFICATION LOGIC ---
  void _eraseStrokeAt(Offset position) {
    final hitObject = hitTest(position);
    
    if (hitObject != null && !_objectsErasedInThisStroke.contains(hitObject.id)) {
      // Add to our set to avoid deleting it multiple times
      _objectsErasedInThisStroke.add(hitObject.id);
      
      // Get the current objects and filter out the deleted ones
      final newObjects = _currentSlide.objects
          .where((obj) => !_objectsErasedInThisStroke.contains(obj.id))
          .toList();

      // Update the state TEMPORARILY (just like in updateSelectionInteraction)
      // This gives a live preview without polluting the undo history.
      final newSlide = _currentSlide.copyWith(objects: newObjects);
      final newSlides = List<Slide>.from(_currentBoard.slides);
      newSlides[_currentBoard.currentSlideIndex] = newSlide;
      
      state = state.copyWith(
        history: [
          ...state.history.sublist(0, state.currentIndex),
          _currentBoard.copyWith(slides: newSlides),
        ],
        currentIndex: state.currentIndex,
      );
    }
  }
  // Utility to get the Rect bounding box for any object
  Rect getBounds(dynamic object) {
    if (object is DrawingObject) {
      final attr = object.attributes;
      final startX = attr.x;
      final startY = attr.y;
      final endX = attr.x + attr.width;
      final endY = attr.y + attr.height;

      // Ensure min/max is used for correct normalized Rect
      return Rect.fromLTRB(
        math.min(startX, endX),
        math.min(startY, endY),
        math.max(startX, endX),
        math.max(startY, endY),
      );
    } else if (object is PenObject) {
      if (object.points.isEmpty) return Rect.zero;

      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = double.negativeInfinity;
      double maxY = double.negativeInfinity;

      for (var p in object.points) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
      // Add padding for stroke width visualization and tolerance
      final padding = object.strokeWidth / 2.0 + 4;
      return Rect.fromLTRB(
        minX - padding,
        minY - padding,
        maxX + padding,
        maxY + padding,
      );
    }
    return Rect.zero;
  }

  // Hit-testing utility
  dynamic hitTest(Offset position) {
    // Iterate in reverse to select the topmost object first
    final objects = _currentSlide.objects.reversed.toList();
    for (var object in objects) {
      final bounds = getBounds(object);
      // Check if the position is within the bounding box (with tolerance)
      if (bounds.inflate(4).contains(position)) {
        return object;
      }
    }
    return null;
  }

  // Handle tap or selection start when in selection tool mode
  void selectObjectAt(
    Offset position,
    WhiteBoard initialBoard,
    bool isShiftOrCtrl,
  ) {
    final selectedObjectIdsNotifier = _ref.read(
      selectedObjectIdsProvider(initialBoard).notifier,
    );
    final currentSelection = selectedObjectIdsNotifier.state;

    // 1. Check for resize handle hit first (only possible if ONE object is selected)
    final selectedObject = currentSelection.length == 1
        ? _currentSlide.objects.firstWhere(
            (obj) => obj.id == currentSelection.single,
            orElse: () => null,
          )
        : null;

    if (selectedObject != null) {
      final hitMode = _hitTestHandles(
        getBounds(selectedObject),
        position,
        selectedObject,
      );
      if (hitMode != SelectionMode.none) {
        _ref.read(selectionModeProvider.notifier).state = hitMode;
        _startPosition = position;
        return;
      }
    }

    // 2. Check for object hit
    final hitObject = hitTest(position);

    if (hitObject != null) {
      final hitId = hitObject.id;

      if (isShiftOrCtrl) {
        // Shift/Ctrl + click selection: Add or remove from selection
        if (currentSelection.contains(hitId)) {
          // Remove object
          selectedObjectIdsNotifier.state = currentSelection
              .where((id) => id != hitId)
              .toSet();
        } else {
          // Add object
          selectedObjectIdsNotifier.state = {...currentSelection, hitId};
        }
      } else {
        // Single selection (or start of drag): select this one object
        selectedObjectIdsNotifier.state = {hitId};
      }

      // If an object is selected/hit, start move mode
      _ref.read(selectionModeProvider.notifier).state = SelectionMode.moving;
      _startPosition = position;
    } else {
      // 3. Tap on empty space: clear selection
      selectedObjectIdsNotifier.state = {};
      _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
      _startPosition = null;
    }
  }

  // Test if a resize handle was hit
  SelectionMode _hitTestHandles(Rect bounds, Offset position, dynamic object) {
    // Resizing only supported for DrawingObjects (shapes) currently
    // We *could* implement PenObject resizing by scaling all points, but we'll stick to shapes for now.
    if (object is! DrawingObject) return SelectionMode.none;

    const double handleSize = 12.0;

    // Define handle rects (centered at corners) on the inflated bounds (for better tapping)
    final inflatedBounds = bounds.inflate(4);

    // Center of the handle circles
    final handles = {
      SelectionMode.resizingTl: inflatedBounds.topLeft,
      SelectionMode.resizingTr: inflatedBounds.topRight,
      SelectionMode.resizingBl: inflatedBounds.bottomLeft,
      SelectionMode.resizingBr: inflatedBounds.bottomRight,
    };

    // Hit-test the circle area around each corner point
    for (var entry in handles.entries) {
      final handleRect = Rect.fromCircle(
        center: entry.value,
        radius: handleSize / 2,
      );
      if (handleRect.contains(position)) {
        return entry.key;
      }
    }
    return SelectionMode.none;
  }

  void updateSelectionInteraction(Offset position) {
    if (_startPosition == null ||
        _ref.read(selectionModeProvider) == SelectionMode.none)
      return;

    final currentMode = _ref.read(selectionModeProvider);
    final selectedIds = _ref.read(selectedObjectIdsProvider(_currentBoard));

    if (selectedIds.isEmpty) return;

    final delta = position - _startPosition!;

    // Create a new list of objects
    List<dynamic> updatedObjects = List.from(_currentSlide.objects);

    for (final id in selectedIds) {
      final index = updatedObjects.indexWhere((obj) => obj.id == id);
      if (index == -1) continue;

      final object = updatedObjects[index];

      if (currentMode == SelectionMode.moving) {
        updatedObjects[index] = _applyMove(object, delta);
      } else if (currentMode.toString().startsWith('resizing')) {
        // Only allow resizing for single selected DrawingObjects
        if (object is DrawingObject && selectedIds.length == 1) {
          updatedObjects[index] = _applyResize(object, delta, currentMode);
        }
      }
    }

    // Update the temporary drawing state with the moved/resized object(s)
    final newSlide = _currentSlide.copyWith(objects: updatedObjects);
    final newSlides = List<Slide>.from(_currentBoard.slides);
    newSlides[_currentBoard.currentSlideIndex] = newSlide;

    // We update the state of the active board directly (without pushNewState yet)
    state = state.copyWith(
      history: [
        ...state.history.sublist(0, state.currentIndex),
        _currentBoard.copyWith(slides: newSlides),
      ],
      currentIndex: state.currentIndex,
    );

    // Update the start position to the current position for continuous delta calculation
    _startPosition = position;
  }

  void commitSelectionInteraction() {
    if (_ref.read(selectionModeProvider) != SelectionMode.none) {
      // This implicitly commits the last temporary state to history
      pushNewState(_currentBoard);
    }
    _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
    _startPosition = null;
  }

  // Helper to apply move logic
  dynamic _applyMove(dynamic object, Offset delta) {
    if (object is PenObject) {
      final movedPoints = object.points
          .map((p) => PointData(x: p.x + delta.dx, y: p.y + delta.dy))
          .toList();
      return object.copyWith(points: movedPoints);
    } else if (object is DrawingObject) {
      final currentAttr = object.attributes;
      final movedAttributes = currentAttr.copyWith(
        x: currentAttr.x + delta.dx,
        y: currentAttr.y + delta.dy,
      );
      return object.copyWith(attributes: movedAttributes);
    }
    return object;
  }

  // Helper to apply resize logic for DrawingObjects
  DrawingObject _applyResize(
    DrawingObject object,
    Offset delta,
    SelectionMode mode,
  ) {
    final currentAttr = object.attributes;

    // Recalculate based on current bounding box (normalized coordinates)
    final currentBounds = getBounds(object);

    Offset anchor; // The corner that stays fixed
    Offset currentHandle; // The corner that moves

    // Determine the anchor (fixed) point and the point being dragged
    switch (mode) {
      case SelectionMode.resizingTl:
        anchor = currentBounds.bottomRight;
        currentHandle = currentBounds.topLeft + delta;
        break;
      case SelectionMode.resizingTr:
        anchor = currentBounds.bottomLeft;
        currentHandle = currentBounds.topRight + delta;
        break;
      case SelectionMode.resizingBl:
        anchor = currentBounds.topRight;
        currentHandle = currentBounds.bottomLeft + delta;
        break;
      case SelectionMode.resizingBr:
        anchor = currentBounds.topLeft;
        currentHandle = currentBounds.bottomRight + delta;
        break;
      default:
        return object;
    }

    // Recalculate new bounding box: [l, t, r, b]
    final l = math.min(anchor.dx, currentHandle.dx);
    final t = math.min(anchor.dy, currentHandle.dy);
    final r = math.max(anchor.dx, currentHandle.dx);
    final b = math.max(anchor.dy, currentHandle.dy);

    // Enforce a minimum size
    const double minSize = 10.0;
    final newWidth = math.max(minSize, r - l);
    final newHeight = math.max(minSize, b - t);

    // Update X, Y based on the new top-left corner (l, t)
    // We re-create attributes to normalize x/y/width/height based on new bounding box
    return object.copyWith(
      attributes: Attributes(
        x: l,
        y: t,
        width: newWidth,
        height: newHeight,
        strokeWidth: currentAttr.strokeWidth,
        strokeColor: currentAttr.strokeColor,
        fillColor: currentAttr.fillColor,
        opacity: currentAttr.opacity,
      ),
    );
  }

  void deleteSelectedObjects(WhiteBoard initialBoard) {
    final selectedIds = _ref.read(selectedObjectIdsProvider(initialBoard));

    if (selectedIds.isEmpty) return;

    final List<dynamic> newObjects = _currentSlide.objects
        .where((obj) => !selectedIds.contains(obj.id))
        .toList();

    final newSlide = _currentSlide.copyWith(objects: newObjects);
    final newSlides = List<Slide>.from(_currentBoard.slides);
    newSlides[_currentBoard.currentSlideIndex] = newSlide;

    final newBoard = _currentBoard.copyWith(slides: newSlides);
    pushNewState(newBoard);

    // Clear selection
    _ref.read(selectedObjectIdsProvider(initialBoard).notifier).state = {};
    _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
  }

  // NEW: Duplicate Selected Objects Logic (Ctrl+D or Alt+Drag)
  void duplicateSelectedObjects(WhiteBoard initialBoard) {
    final selectedIds = _ref.read(selectedObjectIdsProvider(initialBoard));
    if (selectedIds.isEmpty) return;

    final List<dynamic> newObjects = List.from(_currentSlide.objects);
    final Set<String> newSelectedIds = {};
    const double offset = 20.0; // Offset for duplicated objects

    for (var object in _currentSlide.objects) {
      if (selectedIds.contains(object.id)) {
        final String newId = _uuid.v4();
        dynamic newObject;

        if (object is PenObject) {
          final duplicatedPoints = object.points
              .map((p) => PointData(x: p.x + offset, y: p.y + offset))
              .toList();
          newObject = object.copyWith(id: newId, points: duplicatedPoints);
        } else if (object is DrawingObject) {
          final newAttr = object.attributes.copyWith(
            x: object.attributes.x + offset,
            y: object.attributes.y + offset,
          );
          newObject = object.copyWith(id: newId, attributes: newAttr);
        }

        if (newObject != null) {
          newObjects.add(newObject);
          newSelectedIds.add(newId);
        }
      }
    }

    if (newSelectedIds.isNotEmpty) {
      final newSlide = _currentSlide.copyWith(objects: newObjects);
      final newSlides = List<Slide>.from(_currentBoard.slides);
      newSlides[_currentBoard.currentSlideIndex] = newSlide;
      final newBoard = _currentBoard.copyWith(slides: newSlides);

      pushNewState(newBoard);

      // Select the newly duplicated objects
      _ref.read(selectedObjectIdsProvider(initialBoard).notifier).state =
          newSelectedIds;
      _ref.read(selectionModeProvider.notifier).state = SelectionMode.moving;
      // Note: _startPosition is not set here, so the next pan update will use the delta logic.
      // If we wanted to immediately start dragging, we'd need to adjust interaction flow.
    }
  }
}
