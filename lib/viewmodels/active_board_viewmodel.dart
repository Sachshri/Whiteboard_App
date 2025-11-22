import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:white_boarding_app/models/whiteboard_models/drawing_objects.dart';
import 'package:white_boarding_app/models/whiteboard_models/ui_state.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board_history.dart';
import 'package:white_boarding_app/viewmodels/tool_viewmodel.dart';
import 'white_board_viewmodel.dart';
import 'dart:math' as math;

final activeBoardHistoryProvider =
    StateNotifierProvider.family<ActiveBoardNotifier, WhiteBoardHistory, WhiteBoard>(
        (ref, initialBoard) {
  return ActiveBoardNotifier(initialBoard, ref);
});

final currentDrawingObjectProvider = StateProvider<dynamic>((ref) => null);

final selectedObjectIdsProvider = StateProvider.family<Set<String>, WhiteBoard>(
  (ref, initialBoard) => {},
);

final selectionModeProvider = StateProvider.autoDispose<SelectionMode>(
  (ref) => SelectionMode.none,
);

final dragOffsetProvider = StateProvider<Offset?>((ref) => null);
final isShiftControlPressedProvider = StateProvider<bool>((ref) => false);

class ActiveBoardNotifier extends StateNotifier<WhiteBoardHistory> {
  final Ref _ref;
  final Uuid _uuid = const Uuid();
  Offset? _startPosition;
  final Set<String> _objectsErasedInThisStroke = {};

  ActiveBoardNotifier(WhiteBoard initialBoard, this._ref)
      : super(WhiteBoardHistory.initial(initialBoard));

  WhiteBoard get _currentBoard => state.currentBoard;
  Slide get _currentSlide => _currentBoard.slides[_currentBoard.currentSlideIndex];

  // ... [History and Slide Management methods remain unchanged] ...
  // (copy undo, redo, changeSlide, addSlide, deleteSlide, moveSlide from original code)

  void pushNewState(WhiteBoard newState) {
    state = state.push(newState);
    _ref.read(whiteBoardListProvider.notifier).updateWhiteBoard(newState);
  }

  void undo() {
    state = state.undo();
    _ref.read(whiteBoardListProvider.notifier).updateWhiteBoard(_currentBoard);
  }

  void redo() {
    state = state.redo();
    _ref.read(whiteBoardListProvider.notifier).updateWhiteBoard(_currentBoard);
  }
  
  void changeSlide(int newIndex) {
    final newBoard = _currentBoard.copyWith(currentSlideIndex: newIndex);
    pushNewState(newBoard);
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
    final List<Slide> newSlides = List.from(_currentBoard.slides)..removeAt(index);
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
    } else if (oldIndex < _currentBoard.currentSlideIndex && newIndex >= _currentBoard.currentSlideIndex) {
      newCurrentIndex -= 1;
    } else if (oldIndex > _currentBoard.currentSlideIndex && newIndex <= _currentBoard.currentSlideIndex) {
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
        // Create PenObject marked as an eraser
        final PenObject pixelEraser = PenObject(
          id: newId,
          points: [PointData(x: position.dx, y: position.dy)],
          strokeWidth: options.eraserSize,
          color: '#FFFFFF', 
          opacity: 1.0, 
          isEraser: true, // <--- Mark as eraser
        );
        _ref.read(currentDrawingObjectProvider.notifier).state = pixelEraser;
      } else {
        _objectsErasedInThisStroke.clear();
        _eraseStrokeAt(position);
      }
      return; 
    }

    if (type == ToolType.pencil) {
      final PenObject newPen = PenObject(
        id: newId,
        points: [PointData(x: position.dx, y: position.dy)],
        strokeWidth: options.strokeWidth,
        color: options.color,
        opacity: options.opacity,
        isEraser: false, // <--- Regular pen
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
        type: type.toString().split('.').last,
        attributes: Attributes(
          x: position.dx,
          y: position.dy,
          strokeWidth: options.strokeWidth,
          strokeColor: options.color,
          fillColor: options.fillColor,
          opacity: options.opacity,
        ),
      );
      _ref.read(currentDrawingObjectProvider.notifier).state = newShape;
    }
  }

  void updateDrawing(Offset position) {
    final currentObject = _ref.read(currentDrawingObjectProvider);
    
    if (currentObject == null) {
      final activeTool = _ref.read(toolStateProvider);
      final options = _ref.read(toolOptionsProvider);
      if (activeTool == ToolType.eraser && options.eraserMode == EraserMode.stroke) {
        _eraseStrokeAt(position);
      }
      return;
    }

    // PenObject handles both Pencil and Pixel Eraser now
    if (currentObject is PenObject) {
      final updatedPoints = List<PointData>.from(currentObject.points)
        ..add(PointData(x: position.dx, y: position.dy));
      _ref.read(currentDrawingObjectProvider.notifier).state =
          currentObject.copyWith(points: updatedPoints);
    } else if (currentObject is DrawingObject && _startPosition != null) {
      final double newWidth = position.dx - _startPosition!.dx;
      final double newHeight = position.dy - _startPosition!.dy;
      final updatedAttributes = currentObject.attributes.copyWith(
        width: newWidth,
        height: newHeight,
      );
      _ref.read(currentDrawingObjectProvider.notifier).state =
          currentObject.copyWith(attributes: updatedAttributes);
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

    if (currentObject is PenObject && currentObject.points.isNotEmpty) {
      shouldCommit = true;
    } else if (currentObject is DrawingObject &&
        (currentObject.attributes.width.abs() > 2 ||
            currentObject.attributes.height.abs() > 2)) {
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

    _ref.read(currentDrawingObjectProvider.notifier).state = null;
    _startPosition = null;
  }

  // --- MODIFICATION: Stroke Eraser Logic ---
  void _eraseStrokeAt(Offset position) {
    final hitObject = hitTest(position);

    if (hitObject != null && !_objectsErasedInThisStroke.contains(hitObject.id)) {
      _objectsErasedInThisStroke.add(hitObject.id);

      final newObjects = _currentSlide.objects
          .where((obj) => !_objectsErasedInThisStroke.contains(obj.id))
          .toList();

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

  Rect getBounds(dynamic object) {
    if (object is DrawingObject) {
      final attr = object.attributes;
      final startX = attr.x;
      final startY = attr.y;
      final endX = attr.x + attr.width;
      final endY = attr.y + attr.height;
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

  dynamic hitTest(Offset position) {
    final objects = _currentSlide.objects.reversed.toList();
    for (var object in objects) {
      
      if (object is PenObject && object.isEraser) {
        continue;
      }

      final bounds = getBounds(object);
      if (bounds.inflate(4).contains(position)) {
        return object;
      }
    }
    return null;
  }

  void selectObjectAt(Offset position, WhiteBoard initialBoard, bool isShiftOrCtrl) {
    final selectedObjectIdsNotifier = _ref.read(selectedObjectIdsProvider(initialBoard).notifier);
    final currentSelection = selectedObjectIdsNotifier.state;

    final selectedObject = currentSelection.length == 1
        ? _currentSlide.objects.firstWhere(
            (obj) => obj.id == currentSelection.single,
            orElse: () => null,
          )
        : null;

    if (selectedObject != null) {
      final hitMode = _hitTestHandles(getBounds(selectedObject), position, selectedObject);
      if (hitMode != SelectionMode.none) {
        _ref.read(selectionModeProvider.notifier).state = hitMode;
        _startPosition = position;
        return;
      }
    }

    final hitObject = hitTest(position);

    if (hitObject != null) {
      final hitId = hitObject.id;
      if (isShiftOrCtrl) {
        if (currentSelection.contains(hitId)) {
          selectedObjectIdsNotifier.state = currentSelection.where((id) => id != hitId).toSet();
        } else {
          selectedObjectIdsNotifier.state = {...currentSelection, hitId};
        }
      } else {
        selectedObjectIdsNotifier.state = {hitId};
      }
      _ref.read(selectionModeProvider.notifier).state = SelectionMode.moving;
      _startPosition = position;
    } else {
      selectedObjectIdsNotifier.state = {};
      _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
      _startPosition = null;
    }
  }
  
  SelectionMode _hitTestHandles(Rect bounds, Offset position, dynamic object) {
    if (object is! DrawingObject) return SelectionMode.none;
    const double handleSize = 12.0;
    final inflatedBounds = bounds.inflate(4);
    final handles = {
      SelectionMode.resizingTl: inflatedBounds.topLeft,
      SelectionMode.resizingTr: inflatedBounds.topRight,
      SelectionMode.resizingBl: inflatedBounds.bottomLeft,
      SelectionMode.resizingBr: inflatedBounds.bottomRight,
    };
    for (var entry in handles.entries) {
      final handleRect = Rect.fromCircle(center: entry.value, radius: handleSize / 2);
      if (handleRect.contains(position)) return entry.key;
    }
    return SelectionMode.none;
  }

  void updateSelectionInteraction(Offset position) {
    if (_startPosition == null || _ref.read(selectionModeProvider) == SelectionMode.none) return;
    final currentMode = _ref.read(selectionModeProvider);
    final selectedIds = _ref.read(selectedObjectIdsProvider(_currentBoard));
    if (selectedIds.isEmpty) return;
    final delta = position - _startPosition!;
    List<dynamic> updatedObjects = List.from(_currentSlide.objects);

    for (final id in selectedIds) {
      final index = updatedObjects.indexWhere((obj) => obj.id == id);
      if (index == -1) continue;
      final object = updatedObjects[index];
      if (currentMode == SelectionMode.moving) {
        updatedObjects[index] = _applyMove(object, delta);
      } else if (currentMode.toString().startsWith('resizing')) {
        if (object is DrawingObject && selectedIds.length == 1) {
          updatedObjects[index] = _applyResize(object, delta, currentMode);
        }
      }
    }
    final newSlide = _currentSlide.copyWith(objects: updatedObjects);
    final newSlides = List<Slide>.from(_currentBoard.slides);
    newSlides[_currentBoard.currentSlideIndex] = newSlide;
    state = state.copyWith(
      history: [...state.history.sublist(0, state.currentIndex), _currentBoard.copyWith(slides: newSlides)],
      currentIndex: state.currentIndex,
    );
    _startPosition = position;
  }

  void commitSelectionInteraction() {
    if (_ref.read(selectionModeProvider) != SelectionMode.none) {
      pushNewState(_currentBoard);
    }
    _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
    _startPosition = null;
  }

  dynamic _applyMove(dynamic object, Offset delta) {
    if (object is PenObject) {
      final movedPoints = object.points.map((p) => PointData(x: p.x + delta.dx, y: p.y + delta.dy)).toList();
      return object.copyWith(points: movedPoints);
    } else if (object is DrawingObject) {
      final currentAttr = object.attributes;
      final movedAttributes = currentAttr.copyWith(x: currentAttr.x + delta.dx, y: currentAttr.y + delta.dy);
      return object.copyWith(attributes: movedAttributes);
    }
    return object;
  }

  DrawingObject _applyResize(DrawingObject object, Offset delta, SelectionMode mode) {
    final currentAttr = object.attributes;
    final currentBounds = getBounds(object);
    Offset anchor; 
    Offset currentHandle; 
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
    final l = math.min(anchor.dx, currentHandle.dx);
    final t = math.min(anchor.dy, currentHandle.dy);
    final r = math.max(anchor.dx, currentHandle.dx);
    final b = math.max(anchor.dy, currentHandle.dy);
    const double minSize = 10.0;
    final newWidth = math.max(minSize, r - l);
    final newHeight = math.max(minSize, b - t);
    return object.copyWith(
      attributes: Attributes(
        x: l, y: t, width: newWidth, height: newHeight,
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
    final List<dynamic> newObjects = _currentSlide.objects.where((obj) => !selectedIds.contains(obj.id)).toList();
    final newSlide = _currentSlide.copyWith(objects: newObjects);
    final newSlides = List<Slide>.from(_currentBoard.slides);
    newSlides[_currentBoard.currentSlideIndex] = newSlide;
    final newBoard = _currentBoard.copyWith(slides: newSlides);
    pushNewState(newBoard);
    _ref.read(selectedObjectIdsProvider(initialBoard).notifier).state = {};
    _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
  }

  void duplicateSelectedObjects(WhiteBoard initialBoard) {
    final selectedIds = _ref.read(selectedObjectIdsProvider(initialBoard));
    if (selectedIds.isEmpty) return;
    final List<dynamic> newObjects = List.from(_currentSlide.objects);
    final Set<String> newSelectedIds = {};
    const double offset = 20.0;

    for (var object in _currentSlide.objects) {
      if (selectedIds.contains(object.id)) {
        final String newId = _uuid.v4();
        dynamic newObject;
        if (object is PenObject) {
          final duplicatedPoints = object.points.map((p) => PointData(x: p.x + offset, y: p.y + offset)).toList();
          newObject = object.copyWith(id: newId, points: duplicatedPoints);
        } else if (object is DrawingObject) {
          final newAttr = object.attributes.copyWith(x: object.attributes.x + offset, y: object.attributes.y + offset);
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
      _ref.read(selectedObjectIdsProvider(initialBoard).notifier).state = newSelectedIds;
      _ref.read(selectionModeProvider.notifier).state = SelectionMode.moving;
    }
  }
  
  void updateSelectedObjectsAttributes(WhiteBoard initialBoard, {String? strokeColor, String? fillColor}) {
    final selectedIds = _ref.read(selectedObjectIdsProvider(initialBoard));
    if (selectedIds.isEmpty) return;
    List<dynamic> updatedObjects = List.from(_currentSlide.objects);
    for (final id in selectedIds) {
      final index = updatedObjects.indexWhere((obj) => obj.id == id);
      if (index == -1) continue;
      final object = updatedObjects[index];
      if (object is PenObject) {
        updatedObjects[index] = object.copyWith(color: strokeColor ?? object.color);
      } else if (object is DrawingObject) {
        updatedObjects[index] = object.copyWith(
          attributes: object.attributes.copyWith(
            strokeColor: strokeColor ?? object.attributes.strokeColor,
            fillColor: fillColor ?? object.attributes.fillColor,
          ),
        );
      }
    }
    final newSlide = _currentSlide.copyWith(objects: updatedObjects);
    final newSlides = List<Slide>.from(_currentBoard.slides);
    newSlides[_currentBoard.currentSlideIndex] = newSlide;
    final newBoard = _currentBoard.copyWith(slides: newSlides);
    pushNewState(newBoard);
  }

  void startPan(Offset position) { _startPosition = position; }
  
  void updatePan(Offset position) {
    if (_startPosition == null) return;
    final delta = position - _startPosition!;
    if (delta.distanceSquared == 0) return;
    List<dynamic> updatedObjects = List.from(_currentSlide.objects);
    for (int i = 0; i < updatedObjects.length; i++) {
      updatedObjects[i] = _applyMove(updatedObjects[i], delta);
    }
    final newSlide = _currentSlide.copyWith(objects: updatedObjects);
    final newSlides = List<Slide>.from(_currentBoard.slides);
    newSlides[_currentBoard.currentSlideIndex] = newSlide;
    state = state.copyWith(
      history: [...state.history.sublist(0, state.currentIndex), _currentBoard.copyWith(slides: newSlides)],
      currentIndex: state.currentIndex,
    );
    _startPosition = position;
  }

  void endPan() {
    if (_startPosition == null) return;
    pushNewState(_currentBoard);
    _startPosition = null;
  }
}