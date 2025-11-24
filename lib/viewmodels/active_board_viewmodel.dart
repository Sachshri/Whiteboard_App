// lib/viewmodels/active_board_viewmodel.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:white_boarding_app/models/whiteboard_models/drawing_objects.dart';
import 'package:white_boarding_app/models/whiteboard_models/user_cursor_model.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board_history.dart';
import 'package:white_boarding_app/services/websocket_service.dart';
import 'package:white_boarding_app/viewmodels/auth_viewmodel.dart';
import 'package:white_boarding_app/viewmodels/states/auth_state.dart';
import 'package:white_boarding_app/viewmodels/states/whiteboard_ui_state.dart';
import 'package:white_boarding_app/viewmodels/tool_viewmodel.dart';
import 'package:white_boarding_app/viewmodels/white_board_viewmodel.dart';

// 1. Define the Provider for WS Service
final webSocketServiceProvider = Provider((ref) => WebSocketService());
// Provider for Remote Cursors map
final remoteCursorsProvider =
    StateProvider.family<Map<String, UserCursor>, String>((ref, docId) => {});
// 2. Update Notifier Provider to pass WS Service and AuthState
final activeBoardHistoryProvider =
    StateNotifierProvider.family<
      ActiveBoardNotifier,
      WhiteBoardHistory,
      WhiteBoard
    >((ref, initialBoard) {
      final wsService = ref.read(webSocketServiceProvider);
      final authState = ref.read(authProvider);
      return ActiveBoardNotifier(initialBoard, ref, wsService, authState);
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
  final WebSocketService _wsService;
  final AuthState _authState;
  final Uuid _uuid = const Uuid();
  Offset? _startPosition;
  final Set<String> _objectsErasedInThisStroke = {};

  ActiveBoardNotifier(
    WhiteBoard initialBoard,
    this._ref,
    this._wsService,
    this._authState,
  ) : super(WhiteBoardHistory.initial(initialBoard)) {
    // Initialize WS connection if board is synced and user is logged in
    if (initialBoard.isSynced &&
        _authState.isAuthenticated &&
        _authState.user?.token != null) {
      _connectWebSocket(initialBoard.id);
    }
  }

  // --- WEBSOCKET CONNECTION & HANDLERS ---

  void _connectWebSocket(String docId) {
    _wsService.connect(docId, _authState.user!.token!);

    // Listen for incoming updates from other users
    _wsService.onMessageReceived = (data) {
      _handleIncomingMessage(data);
    };
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    // 1. Echo Cancellation: Ignore messages sent by ourselves
    if (data['userId'] == _authState.user?.id) return;

    // 2. Parse the 'body' string (Backend sends JSON string inside 'body')
    if (data['body'] != null) {
      try {
        final bodyContent = data['body'];

        // If the backend sends a simple string (e.g. from an old version), ignore or handle gracefully
        if (bodyContent is! String || !bodyContent.trim().startsWith('{')) {
          debugPrint("[WS] Received non-JSON body: $bodyContent");
          return;
        }

        final actionData = jsonDecode(bodyContent);
        final action = actionData['action'];

        debugPrint("[WS] Received Action: $action");

        // 3. Handle 'create' action to update local state from remote
        switch (action) {
          case 'create':
            _applyRemoteCreation(actionData);
            break;
          case 'update':
            _applyRemoteUpdate(actionData);
            break;
          case 'delete':
            _applyRemoteDelete(actionData);
            break;
          case 'cursormove':
            _applyRemoteCursorMove(
              actionData,
              data['username'] ?? 'Anon',
              data['userId'],
            );
            break;
        }
      } catch (e) {
        debugPrint("[WS] Error parsing message body: $e");
      }
    }
  }

  void _applyRemoteCreation(Map<String, dynamic> data) {
    try {
      final String objectType = data['objectType'];
      final String objectId = data['objectId'];
      final Map<String, dynamic> attributes = data['attributes'];

      dynamic newObject;

      if (objectType == 'pen') {
        // Parse Pen Points
        List<PointData> pointsList = [];
        if (attributes['points'] != null && attributes['points'] is List) {
          pointsList = (attributes['points'] as List).map((p) {
            // Handle potential int/double mismatch from JSON
            return PointData(
              x: (p['x'] as num).toDouble(),
              y: (p['y'] as num).toDouble(),
            );
          }).toList();
        }

        newObject = PenObject(
          id: objectId,
          points: pointsList,
          strokeWidth: (attributes['strokeWidth'] as num).toDouble(),
          color: attributes['strokeColor'] ?? attributes['color'] ?? '#000000',
          opacity: (attributes['opacity'] as num?)?.toDouble() ?? 1.0,
          isEraser: false,
        );
      } else {
        // Parse Shapes (Rect, Circle, Line, Arrow)
        newObject = DrawingObject(
          id: objectId,
          type: objectType,
          attributes: Attributes(
            x: (attributes['x'] as num).toDouble(),
            y: (attributes['y'] as num).toDouble(),
            width: (attributes['width'] as num).toDouble(),
            height: (attributes['height'] as num).toDouble(),
            strokeWidth: (attributes['strokeWidth'] as num).toDouble(),
            strokeColor: attributes['strokeColor'] ?? '#000000',
            fillColor: attributes['fillColor'] ?? '#FFFFFF',
            opacity: (attributes['opacity'] as num?)?.toDouble() ?? 1.0,
            // Map Text specific fields
            text: attributes['value'],
            fontSize: (attributes['fontWidth'] as num?)?.toDouble() ?? 20.0,
          ),
        );
      }

      if (newObject != null) {
        // Add to current slide
        final currentSlide =
            state.currentBoard.slides[state.currentBoard.currentSlideIndex];
        final newObjects = List.from(currentSlide.objects)..add(newObject);
        final newSlide = currentSlide.copyWith(objects: newObjects);

        final newSlides = List<Slide>.from(state.currentBoard.slides);
        newSlides[state.currentBoard.currentSlideIndex] = newSlide;

        // Update State without triggering a new "Push" to backend
        state = state.copyWith(
          history: [
            ...state.history.sublist(0, state.currentIndex + 1),
            state.currentBoard.copyWith(slides: newSlides),
          ],
          currentIndex: state.currentIndex + 1,
        );
      }
    } catch (e) {
      debugPrint("[WS] Error applying remote creation: $e");
    }
  }

  void _applyRemoteUpdate(Map<String, dynamic> data) {
    final objectId = data['objectId'];
    final updatedAttrs = data['updatedAttributes'] as Map<String, dynamic>;

    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    final index = currentSlide.objects.indexWhere((obj) => obj.id == objectId);

    if (index == -1) return;

    var object = currentSlide.objects[index];

    // Helper to merge attributes
    if (object is DrawingObject) {
      // Create a new Attributes object merging old + new
      // Note: This requires mapping the JSON keys back to Dart property names
      // (e.g. 'strokeColor' -> strokeColor)
      final oldAttr = object.attributes.toJson();
      final newAttrMap = {...oldAttr, ...updatedAttrs}; // Simple merge
      object = object.copyWith(attributes: Attributes.fromJson(newAttrMap));
    }
    // Logic for PenObject updates (if any) would go here

    // Update State
    _updateObjectInState(index, object);
  }

  void _applyRemoteDelete(Map<String, dynamic> data) {
    final objectId = data['objectId'];
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    final newObjects = currentSlide.objects
        .where((obj) => obj.id != objectId)
        .toList();

    _updateSlideObjectsInState(newObjects);
  }

  void _applyRemoteCursorMove(
    Map<String, dynamic> data,
    String username,
    String userId,
  ) {
    final loc = data['newCursorLocation'] as List;
    final dx = (loc[0] as num).toDouble();
    final dy = (loc[1] as num).toDouble();

    final currentCursors = _ref.read(
      remoteCursorsProvider(state.currentBoard.id),
    );
    final newCursor = UserCursor(
      userId: userId,
      username: username,
      position: Offset(dx, dy),
      color:
          Colors.primaries[userId.hashCode %
              Colors.primaries.length], // Consistent color
    );

    _ref.read(remoteCursorsProvider(state.currentBoard.id).notifier).state = {
      ...currentCursors,
      userId: newCursor,
    };
  }

  // --- STATE HELPERS ---

  void _updateObjectInState(int index, dynamic newObject) {
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    final newObjects = List<dynamic>.from(currentSlide.objects);
    newObjects[index] = newObject;
    _updateSlideObjectsInState(newObjects);
  }

  void _updateSlideObjectsInState(List<dynamic> newObjects) {
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    final newSlide = currentSlide.copyWith(objects: newObjects);
    final newSlides = List<Slide>.from(state.currentBoard.slides);
    newSlides[state.currentBoard.currentSlideIndex] = newSlide;

    // Direct state update (No push to history for remote updates to avoid undo stack corruption)
    state = state.copyWith(
      history: [
        ...state.history.sublist(0, state.currentIndex),
        state.currentBoard.copyWith(slides: newSlides),
      ],
      currentIndex: state.currentIndex,
    );
  }

  // --- OUTGOING EVENT SENDERS ---

  void sendCursorMove(Offset position) {
    if (!state.currentBoard.isSynced) return;

    // Throttling could be added here to reduce network load
    final msg = {
      "action": "cursormove",
      "slideId":
          state.currentBoard.slides[state.currentBoard.currentSlideIndex].id,
      "newCursorLocation": [position.dx, position.dy],
    };
    _wsService.send(msg);
  }

  // void sendUpdateMessage(dynamic object) {
  //   if (!state.currentBoard.isSynced) return;

  //   Map<String, dynamic> attributes = {};
  //   if(object is DrawingObject) attributes = object.attributes.toJson();

  //   final msg = {
  //      "action": "update",
  //      "slideId": state.currentBoard.slides[state.currentBoard.currentSlideIndex].id,
  //      "objectId": object.id,
  //      "objectType": object is PenObject ? "pen" : object.type,
  //      "updatedAttributes": attributes
  //   };
  //   _wsService.send(msg);
  // }

  // void sendDeleteMessage(String objectId, String type) {
  //   if (!state.currentBoard.isSynced) return;
  //   final msg = {
  //      "action": "delete",
  //      "slideId": state.currentBoard.slides[state.currentBoard.currentSlideIndex].id,
  //      "objectId": objectId,
  //      "objectType": type,
  //   };
  //   _wsService.send(msg);
  // }
  // --- ADD THESE NEW METHODS ---

  void sendUpdateMessage(dynamic object) {
    // 1. Check if board is online
    if (!state.currentBoard.isSynced) return;

    Map<String, dynamic> attributes = {};
    String objectType = '';

    // 2. Map Frontend Object to Backend Attributes
    if (object is DrawingObject) {
      objectType = object.type;

      // Start with standard attributes (x, y, width, height, strokeWidth, etc.)
      attributes = object.attributes.toJson();

      // --- BACKEND VALIDATION MAPPING ---

      // Fix for Circles: Backend requires 'cx', 'cy', 'radius'
      if (objectType == 'circle') {
        final double radius =
            (math.min(
                      object.attributes.width.abs(),
                      object.attributes.height.abs(),
                    ) /
                    2)
                .abs();
        attributes['cx'] = object.attributes.x + (object.attributes.width / 2);
        attributes['cy'] = object.attributes.y + (object.attributes.height / 2);
        attributes['radius'] = radius;
      }

      if (objectType == 'text') {
        attributes['bx'] = object.attributes.x;
        attributes['by'] = object.attributes.y;
        attributes['value'] = object.attributes.text ?? "";
        attributes['textColor'] = object.attributes.strokeColor;
        attributes['fontWidth'] = object.attributes.fontSize;
        attributes['font'] = 'Arial';
      }
    } else if (object is PenObject) {
      objectType = 'pen';
      // Fix for Pens: Backend needs the updated points array if the pen moved
      attributes = {
        "points": object.points.map((p) => {'x': p.x, 'y': p.y}).toList(),
        "color": object.color,
        "strokeWidth": object.strokeWidth,
        "opacity": object.opacity,
      };
    }

    // 3. Construct the Message
    final msg = {
      "action": "update",
      "slideId":
          state.currentBoard.slides[state.currentBoard.currentSlideIndex].id,
      "objectId": object.id,
      "objectType": objectType,
      "updatedAttributes": attributes,
    };

    // 4. Send
    _wsService.send(msg);
  }

  void sendDeleteMessage(String objectId, String type, String slideId) {
    if (!state.currentBoard.isSynced) return;

    final msg = {
      "action": "delete",
      "slideId": slideId,
      "objectId": objectId,
      "objectType": type,
    };
    _wsService.send(msg);
  }

  void _sendCreateMessage(dynamic object, String slideId) {
    Map<String, dynamic> attributes = {};
    String objectType = '';

    if (object is DrawingObject) {
      objectType = object.type;

      // Map Dart Attributes to Backend Expected JSON
      attributes = {
        "x": object.attributes.x,
        "y": object.attributes.y,
        "width": object.attributes.width,
        "height": object.attributes.height,
        "strokeWidth": object.attributes.strokeWidth.toInt(),
        "strokeColor": object.attributes.strokeColor,
        "fillColor": object.attributes.fillColor,
        // Specific validators in Go backend require these for Circles
        if (objectType == 'circle') ...{
          "cx": object.attributes.x + (object.attributes.width / 2),
          "cy": object.attributes.y + (object.attributes.height / 2),
          "radius":
              (math.min(
                        object.attributes.width.abs(),
                        object.attributes.height.abs(),
                      ) /
                      2)
                  .abs(),
        },
        // Add box coordinates for Text if needed by backend
        if (objectType == 'text') ...{
          "bx": object.attributes.x,
          "by": object.attributes.y,
          "value": object.attributes.text ?? "",
          "textColor": object.attributes.strokeColor,
          "font": "Arial", // Default
          "fontWidth": object.attributes.fontSize.toInt(),
        },
      };
    } else if (object is PenObject) {
      // Map Pen points
      objectType = 'pen'; // Ensure backend handles 'pen' or map to 'line'
      attributes = {
        "points": object.points.map((p) => {'x': p.x, 'y': p.y}).toList(),
        "color": object.color,
        "strokeWidth": object.strokeWidth,
      };
    }

    final msg = {
      "action": "create",
      "slideId": slideId,
      "objectId": object.id,
      "objectType": objectType,
      "attributes": attributes,
    };

    _wsService.send(msg);
  }

  // --- STANDARD STATE MANAGEMENT ---

  void pushNewState(WhiteBoard newState) {
    state = state.push(newState);
    _ref.read(whiteBoardListProvider.notifier).updateWhiteBoard(newState);
  }

  void undo() {
    state = state.undo();
    _ref
        .read(whiteBoardListProvider.notifier)
        .updateWhiteBoard(state.currentBoard);
  }

  void redo() {
    state = state.redo();
    _ref
        .read(whiteBoardListProvider.notifier)
        .updateWhiteBoard(state.currentBoard);
  }

  void changeSlide(int newIndex) {
    final newBoard = state.currentBoard.copyWith(currentSlideIndex: newIndex);
    pushNewState(newBoard);
    _ref.read(selectedObjectIdsProvider(newBoard).notifier).state = {};
  }

  void addSlide() {
    final newSlide = Slide(id: _uuid.v4());
    final List<Slide> newSlides = [...state.currentBoard.slides, newSlide];
    final newBoard = state.currentBoard.copyWith(
      slides: newSlides,
      currentSlideIndex: newSlides.length - 1,
    );
    pushNewState(newBoard);
  }

  void deleteSlide(int index) {
    if (state.currentBoard.slides.length <= 1) return;
    final List<Slide> newSlides = List.from(state.currentBoard.slides)
      ..removeAt(index);
    int newIndex = state.currentBoard.currentSlideIndex;
    if (newIndex >= newSlides.length) {
      newIndex = newSlides.length - 1;
    }
    final newBoard = state.currentBoard.copyWith(
      slides: newSlides,
      currentSlideIndex: newIndex,
    );
    pushNewState(newBoard);
  }

  void moveSlide(int oldIndex, int newIndex) {
    final List<Slide> newSlides = List.from(state.currentBoard.slides);
    final slideToMove = newSlides.removeAt(oldIndex);
    newSlides.insert(newIndex, slideToMove);
    int newCurrentIndex = state.currentBoard.currentSlideIndex;
    if (oldIndex == state.currentBoard.currentSlideIndex) {
      newCurrentIndex = newIndex;
    } else if (oldIndex < state.currentBoard.currentSlideIndex &&
        newIndex >= state.currentBoard.currentSlideIndex) {
      newCurrentIndex -= 1;
    } else if (oldIndex > state.currentBoard.currentSlideIndex &&
        newIndex <= state.currentBoard.currentSlideIndex) {
      newCurrentIndex += 1;
    }
    final newBoard = state.currentBoard.copyWith(
      slides: newSlides,
      currentSlideIndex: newCurrentIndex,
    );
    pushNewState(newBoard);
  }

  // --- DRAWING INTERACTION LOGIC ---

  void startDrawing(Offset position, ToolOptions options, ToolType type) {
    _startPosition = position;
    final String newId = _uuid.v4();

    if (type == ToolType.eraser) {
      if (options.eraserMode == EraserMode.pixel) {
        final PenObject pixelEraser = PenObject(
          id: newId,
          points: [PointData(x: position.dx, y: position.dy)],
          strokeWidth: options.eraserSize,
          color: '#FFFFFF',
          opacity: 1.0,
          isEraser: true,
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
        isEraser: false,
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
      if (activeTool == ToolType.eraser &&
          options.eraserMode == EraserMode.stroke) {
        _eraseStrokeAt(position);
      }
      return;
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

    // 1. Handle Eraser Commit
    if (activeTool == ToolType.eraser &&
        options.eraserMode == EraserMode.stroke &&
        _objectsErasedInThisStroke.isNotEmpty) {
      pushNewState(state.currentBoard);
      _objectsErasedInThisStroke.clear();
      return;
    }

    if (currentObject == null) {
      _startPosition = null;
      return;
    }

    // 2. Validate Object
    if (currentObject is PenObject && currentObject.points.isNotEmpty) {
      shouldCommit = true;
    } else if (currentObject is DrawingObject &&
        (currentObject.attributes.width.abs() > 2 ||
            currentObject.attributes.height.abs() > 2)) {
      shouldCommit = true;
    }

    // 3. Commit Object
    if (shouldCommit) {
      final currentSlide =
          state.currentBoard.slides[state.currentBoard.currentSlideIndex];

      final List<dynamic> newObjects = List.from(currentSlide.objects)
        ..add(currentObject);

      final newSlide = currentSlide.copyWith(objects: newObjects);
      final newSlides = List<Slide>.from(state.currentBoard.slides);
      newSlides[state.currentBoard.currentSlideIndex] = newSlide;

      final newBoard = state.currentBoard.copyWith(slides: newSlides);
      pushNewState(newBoard);

      // 4. Sync with WebSocket
      if (state.currentBoard.isSynced) {
        _sendCreateMessage(currentObject, currentSlide.id);
      }
    }

    _ref.read(currentDrawingObjectProvider.notifier).state = null;
    _startPosition = null;
  }

  // --- HELPER LOGIC ---

  void _eraseStrokeAt(Offset position) {
    final hitObject = hitTest(position);
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];

    if (hitObject != null &&
        !_objectsErasedInThisStroke.contains(hitObject.id)) {
      _objectsErasedInThisStroke.add(hitObject.id);

      final newObjects = currentSlide.objects
          .where((obj) => !_objectsErasedInThisStroke.contains(obj.id))
          .toList();

      final newSlide = currentSlide.copyWith(objects: newObjects);
      final newSlides = List<Slide>.from(state.currentBoard.slides);
      newSlides[state.currentBoard.currentSlideIndex] = newSlide;

      state = state.copyWith(
        history: [
          ...state.history.sublist(0, state.currentIndex),
          state.currentBoard.copyWith(slides: newSlides),
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
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    final objects = currentSlide.objects.reversed.toList();
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

  void selectObjectAt(
    Offset position,
    WhiteBoard initialBoard,
    bool isShiftOrCtrl,
  ) {
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    final selectedObjectIdsNotifier = _ref.read(
      selectedObjectIdsProvider(initialBoard).notifier,
    );
    final currentSelection = selectedObjectIdsNotifier.state;

    final selectedObject = currentSelection.length == 1
        ? currentSlide.objects.firstWhere(
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

    final hitObject = hitTest(position);

    if (hitObject != null) {
      final hitId = hitObject.id;
      if (isShiftOrCtrl) {
        if (currentSelection.contains(hitId)) {
          selectedObjectIdsNotifier.state = currentSelection
              .where((id) => id != hitId)
              .toSet();
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
      final handleRect = Rect.fromCircle(
        center: entry.value,
        radius: handleSize / 2,
      );
      if (handleRect.contains(position)) return entry.key;
    }
    return SelectionMode.none;
  }

  void updateSelectionInteraction(Offset position) {
    if (_startPosition == null ||
        _ref.read(selectionModeProvider) == SelectionMode.none)
      return;
    final currentMode = _ref.read(selectionModeProvider);
    final selectedIds = _ref.read(
      selectedObjectIdsProvider(state.currentBoard),
    );
    if (selectedIds.isEmpty) return;
    final delta = position - _startPosition!;
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    List<dynamic> updatedObjects = List.from(currentSlide.objects);

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
    final newSlide = currentSlide.copyWith(objects: updatedObjects);
    final newSlides = List<Slide>.from(state.currentBoard.slides);
    newSlides[state.currentBoard.currentSlideIndex] = newSlide;
    state = state.copyWith(
      history: [
        ...state.history.sublist(0, state.currentIndex),
        state.currentBoard.copyWith(slides: newSlides),
      ],
      currentIndex: state.currentIndex,
    );
    _startPosition = position;
  }

  // void commitSelectionInteraction() {
  //   if (_ref.read(selectionModeProvider) != SelectionMode.none) {
  //     pushNewState(state.currentBoard);
  //   }
  //   _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
  //   _startPosition = null;
  // }
  void commitSelectionInteraction() {
    // 1. Check if we were actually doing something
    if (_ref.read(selectionModeProvider) != SelectionMode.none) {
      // 2. Identify which objects were modified
      // (The state is already updated by updateSelectionInteraction, we just need to read the current values)
      final selectedIds = _ref.read(
        selectedObjectIdsProvider(state.currentBoard),
      );
      final currentSlide =
          state.currentBoard.slides[state.currentBoard.currentSlideIndex];

      // 3. Send Update Message for each selected object
      if (state.currentBoard.isSynced) {
        for (var obj in currentSlide.objects) {
          if (selectedIds.contains(obj.id)) {
            sendUpdateMessage(obj);
          }
        }
      }

      // 4. Save to history
      pushNewState(state.currentBoard);
    }

    _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
    _startPosition = null;
  }

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

  DrawingObject _applyResize(
    DrawingObject object,
    Offset delta,
    SelectionMode mode,
  ) {
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
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    if (state.currentBoard.isSynced) {
      final objectsToDelete = currentSlide.objects.where(
        (obj) => selectedIds.contains(obj.id),
      );
      for (var obj in objectsToDelete) {
        String type = '';
        if (obj is DrawingObject) type = obj.type;
        if (obj is PenObject) type = 'pen';

        sendDeleteMessage(obj.id, type, currentSlide.id);
      }
    }
    final List<dynamic> newObjects = currentSlide.objects
        .where((obj) => !selectedIds.contains(obj.id))
        .toList();
    final newSlide = currentSlide.copyWith(objects: newObjects);
    final newSlides = List<Slide>.from(state.currentBoard.slides);
    newSlides[state.currentBoard.currentSlideIndex] = newSlide;
    final newBoard = state.currentBoard.copyWith(slides: newSlides);
    pushNewState(newBoard);
    _ref.read(selectedObjectIdsProvider(initialBoard).notifier).state = {};
    _ref.read(selectionModeProvider.notifier).state = SelectionMode.none;
  }

  void duplicateSelectedObjects(WhiteBoard initialBoard) {
    final selectedIds = _ref.read(selectedObjectIdsProvider(initialBoard));
    if (selectedIds.isEmpty) return;
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];

    final List<dynamic> newObjects = List.from(currentSlide.objects);
    final Set<String> newSelectedIds = {};
    const double offset = 20.0;

    for (var object in currentSlide.objects) {
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
      final newSlide = currentSlide.copyWith(objects: newObjects);
      final newSlides = List<Slide>.from(state.currentBoard.slides);
      newSlides[state.currentBoard.currentSlideIndex] = newSlide;
      final newBoard = state.currentBoard.copyWith(slides: newSlides);
      pushNewState(newBoard);
      _ref.read(selectedObjectIdsProvider(initialBoard).notifier).state =
          newSelectedIds;
      _ref.read(selectionModeProvider.notifier).state = SelectionMode.moving;
    }
  }

  void updateSelectedObjectsAttributes(
    WhiteBoard initialBoard, {
    String? strokeColor,
    String? fillColor,
  }) {
    final selectedIds = _ref.read(selectedObjectIdsProvider(initialBoard));
    if (selectedIds.isEmpty) return;
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    List<dynamic> updatedObjects = List.from(currentSlide.objects);
    for (final id in selectedIds) {
      final index = updatedObjects.indexWhere((obj) => obj.id == id);
      if (index == -1) continue;
      final object = updatedObjects[index];
      if (object is PenObject) {
        updatedObjects[index] = object.copyWith(
          color: strokeColor ?? object.color,
        );
      } else if (object is DrawingObject) {
        updatedObjects[index] = object.copyWith(
          attributes: object.attributes.copyWith(
            strokeColor: strokeColor ?? object.attributes.strokeColor,
            fillColor: fillColor ?? object.attributes.fillColor,
          ),
        );
      }
    }
    final newSlide = currentSlide.copyWith(objects: updatedObjects);
    final newSlides = List<Slide>.from(state.currentBoard.slides);
    newSlides[state.currentBoard.currentSlideIndex] = newSlide;
    final newBoard = state.currentBoard.copyWith(slides: newSlides);
    pushNewState(newBoard);
  }

  void startPan(Offset position) {
    _startPosition = position;
  }

  void updatePan(Offset position) {
    if (_startPosition == null) return;
    final delta = position - _startPosition!;
    if (delta.distanceSquared == 0) return;
    final currentSlide =
        state.currentBoard.slides[state.currentBoard.currentSlideIndex];
    List<dynamic> updatedObjects = List.from(currentSlide.objects);
    for (int i = 0; i < updatedObjects.length; i++) {
      updatedObjects[i] = _applyMove(updatedObjects[i], delta);
    }
    final newSlide = currentSlide.copyWith(objects: updatedObjects);
    final newSlides = List<Slide>.from(state.currentBoard.slides);
    newSlides[state.currentBoard.currentSlideIndex] = newSlide;
    state = state.copyWith(
      history: [
        ...state.history.sublist(0, state.currentIndex),
        state.currentBoard.copyWith(slides: newSlides),
      ],
      currentIndex: state.currentIndex,
    );
    _startPosition = position;
  }

  void endPan() {
    if (_startPosition == null) return;
    pushNewState(state.currentBoard);
    _startPosition = null;
  }
}
