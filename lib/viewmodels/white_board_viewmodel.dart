import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:white_boarding_app/models/whiteboard_models/drawing_objects.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';
import 'package:white_boarding_app/repositories/document_repository.dart';
import 'package:white_boarding_app/services/websocket_service.dart';
import 'package:white_boarding_app/viewmodels/active_board_viewmodel.dart'; 
import 'package:white_boarding_app/viewmodels/auth_viewmodel.dart';
import 'package:white_boarding_app/utils/helpers/network_manager.dart';

final whiteBoardListProvider =
    StateNotifierProvider<WhiteBoardListNotifier, List<WhiteBoard>>((ref) {
  
  final wsService = ref.read(webSocketServiceProvider);
  return WhiteBoardListNotifier(ref, wsService);
});

class WhiteBoardListNotifier extends StateNotifier<List<WhiteBoard>> {
  final Ref _ref;
  final WebSocketService _wsService;
  final DocumentRepository _docRepo = DocumentRepository();
  static const String _whiteBoardsKey = 'WhiteBoards_list';
  final Uuid _uuid = const Uuid();

  WhiteBoardListNotifier(this._ref, this._wsService) : super([]) {
    _loadWhiteBoards();
  }

  Future<void> _loadWhiteBoards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? whiteBoardsJson = prefs.getString(_whiteBoardsKey);

    if (whiteBoardsJson != null) {
      final List<dynamic> jsonList = jsonDecode(whiteBoardsJson);
      state = jsonList
          .map((json) => WhiteBoard.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_whiteBoardsKey, jsonStr);
  }

  WhiteBoard createNewWhiteBoard(String title) {
    
    final newWhiteBoard = WhiteBoard(
      id: _uuid.v4(),
      title: title,
      creationDate: DateFormat("yyyy/MM/dd HH:mm:ss").format(DateTime.now()),
      slides: [Slide(id: _uuid.v4())],
      isSynced: false,
    );

    state = [...state, newWhiteBoard];
    _saveLocal();
    return newWhiteBoard;
  }

  void updateWhiteBoard(WhiteBoard updatedWhiteBoard) {
    state = state
        .map((wb) => wb.id == updatedWhiteBoard.id ? updatedWhiteBoard : wb)
        .toList();
    _saveLocal();
  }
  Future<void> renameBoard(String boardId, String newTitle) async {
    // 1. Update Local
    state = state.map((b) {
      if (b.id == boardId) {
        return b.copyWith(title: newTitle);
      }
      return b;
    }).toList();
    _saveLocal();

    // 2. Update Remote (Optional: If your backend supports renaming via HTTP)
    // currently your backend doesn't seem to have a Rename API, 
    // it usually happens via WebSocket update on the document title object
  }
  Future<void> deleteBoard(String id) async {
    final boardToDelete = state.firstWhere(
      (b) => b.id == id,
      orElse: () => WhiteBoard(id: 'err', title: '', creationDate: ''),
    );
    if (boardToDelete.id == 'err') return;

    state = state.where((wb) => wb.id != id).toList();
    _saveLocal();

    final authState = _ref.read(authProvider);
    final isConnected = await _ref.read(networkManagerProvider.notifier).isConnected();

    if (boardToDelete.isSynced && isConnected && authState.isAuthenticated) {
      try {
        final success = await _docRepo.deleteDocument(authState.user!.token!, id);
        if (!success) {
           debugPrint("Server delete returned false, but local is deleted.");
        }
      } catch (e) {
        debugPrint("Server delete failed: $e");
      }
    }
  }
  Future<void> syncWithBackend() async {
    final authState = _ref.read(authProvider);
    final isConnected =
        await _ref.read(networkManagerProvider.notifier).isConnected();

    if (!isConnected) throw Exception("No Internet Connection");
    if (!authState.isAuthenticated) throw Exception("User not logged in");
    final token = authState.user!.token!;
    try {
      List<WhiteBoard> updatedList = [...state];

      for (int i = 0; i < updatedList.length; i++) {
        var board = updatedList[i];

        
        if (!board.isSynced) {
          debugPrint("[Sync] Creating board '${board.title}' on server...");

          
          final newServerId = await _docRepo.createDocument(token);
          final oldId = board.id;
          board = board.copyWith(
            id: newServerId,
            isSynced: true,
          );
          updatedList[i] = board;

          debugPrint("[Sync] Pushing local content for $oldId -> $newServerId");
          await _pushInitialContent(board, token);
        }
      }

      
      final serverDocs = await _docRepo.getAllDocuments(token);

      for (var serverDoc in serverDocs) {
        final localIndex = updatedList.indexWhere((l) => l.id == serverDoc.id);

        if (localIndex == -1) {
          
          updatedList.add(serverDoc.copyWith(isSynced: true));
        } else {
          
          updatedList[localIndex] =
              updatedList[localIndex].copyWith(isSynced: true);
        }
      }

      state = updatedList;
      _saveLocal();
    } catch (e) {
      debugPrint("Sync Error: $e");
      rethrow;
    }
  }

  
  Future<void> _pushInitialContent(WhiteBoard board, String token) async {
    // 1. Create a NEW, isolated instance just for this operation
    final WebSocketService tempWsService = WebSocketService();

    try {
      debugPrint("[Sync] Connecting isolated WS for board: ${board.id}");
      
      // 2. Connect using the temp instance
      tempWsService.connect(board.id, token);

      // Wait for connection to establish (Simple polling mechanism)
      int retries = 0;
      while (retries < 5) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      for (var slide in board.slides) {
        debugPrint("Pushing Slide: ${slide.id}");
        final addSlideMsg = {
          "action": "add_slide",
          "slideId": slide.id,
        };
        
        // 3. Send using the temp instance
        tempWsService.send(addSlideMsg);

        await Future.delayed(const Duration(milliseconds: 50));

        for (var object in slide.objects) {
          final createMsg = _mapObjectToCreateMessage(object, slide.id);
          if (createMsg != null) {
            // 3. Send using the temp instance
            tempWsService.send(createMsg);
          }
        }
      }
      
      // Allow buffer time for messages to flush out to the network
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 4. Disconnect ONLY the temp instance
      tempWsService.disconnect();
      debugPrint("[Sync] Isolated WS disconnected.");

    } catch (e) {
      debugPrint("[Sync] Failed to push content via WS: $e");
      // Ensure we cleanup the temp connection on error
      tempWsService.disconnect();
    }
  }

  
  Map<String, dynamic>? _mapObjectToCreateMessage(
      dynamic object, String slideId) {
    Map<String, dynamic> attributes = {};
    String objectType = '';

    if (object is DrawingObject) {
      objectType = object.type;
      attributes = {
        "x": object.attributes.x,
        "y": object.attributes.y,
        "width": object.attributes.width,
        "height": object.attributes.height,
        "strokeWidth": object.attributes.strokeWidth.toInt(),
        "strokeColor": object.attributes.strokeColor,
        "fillColor": object.attributes.fillColor,
        if (objectType == 'circle') ...{
          "cx": object.attributes.x + (object.attributes.width / 2),
          "cy": object.attributes.y + (object.attributes.height / 2),
          "radius": (math.min(object.attributes.width.abs(),
                      object.attributes.height.abs()) /
                  2)
              .abs(),
        },
        if (objectType == 'text') ...{
          "bx": object.attributes.x,
          "by": object.attributes.y,
          "value": object.attributes.text ?? "",
          "textColor": object.attributes.strokeColor,
          "font": "Arial",
          "fontWidth": object.attributes.fontSize,
        }
      };
    } else if (object is PenObject) {
      if (object.points.isEmpty) return null;
      objectType = 'pen';
      attributes = {
        "points": object.points.map((p) => {'x': p.x, 'y': p.y}).toList(),
        "color": object.color,
        "strokeColor": object.color, 
        "strokeWidth": object.strokeWidth,
        "opacity": object.opacity, 
      };
    } else {
      return null;
    }

    return {
      "action": "create",
      "slideId": slideId,
      "objectId": object.id,
      "objectType": objectType,
      "attributes": attributes,
    };
  }
}