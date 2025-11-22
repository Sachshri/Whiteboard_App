import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';

final whiteBoardListProvider =
    StateNotifierProvider<WhiteBoardListNotifier, List<WhiteBoard>>((ref) {
      return WhiteBoardListNotifier();
    });

class WhiteBoardListNotifier extends StateNotifier<List<WhiteBoard>> {
  WhiteBoardListNotifier() : super([]) {
    _loadWhiteBoards();
  }

  static const String _whiteBoardsKey = 'WhiteBoards_list';
  final Uuid _uuid = const Uuid();

  // 1. Load WhiteBoards from local storage
  Future<void> _loadWhiteBoards() async {
    final prefs = await SharedPreferences.getInstance();
    final String? whiteBoardsJson = prefs.getString(_whiteBoardsKey);

    if (whiteBoardsJson != null) {
      // Decode the outer list
      final List<dynamic> jsonList = jsonDecode(whiteBoardsJson);
      // Map each item to a WhiteBoard object
      state = jsonList
          .map((json) => WhiteBoard.fromJson(json as Map<String, dynamic>))
          .toList();
    } else {
      state = [];
    }
  }

  // 2. Save all WhiteBoards to local storage
  Future<void> _saveWhiteBoards() async {
    final prefs = await SharedPreferences.getInstance();
    final String whiteBoardListJsonString = jsonEncode(state.map((whiteBoard) => whiteBoard.toJson()).toList());
    await prefs.setString(_whiteBoardsKey, whiteBoardListJsonString);
  }

  // 3. Create a New WhiteBoard
  WhiteBoard createNewWhiteBoard(String title) {
    final newWhiteBoard = WhiteBoard(
      id: _uuid.v4(),
      title: title,
      creationDate: DateFormat("yyyy/MM/dd HH:mm:ss").format(DateTime.now()),
      slides: [Slide(id: _uuid.v4())],
    );

    state = [...state, newWhiteBoard];
    _saveWhiteBoards();
    return newWhiteBoard;
  }

  void updateWhiteBoard(WhiteBoard updatedWhiteBoard) {
    state = state
        .map((whiteBoard) => whiteBoard.id == updatedWhiteBoard.id ? updatedWhiteBoard : whiteBoard)
        .toList();
    _saveWhiteBoards();
  }

  Future<void> deleteBoard(String id) async {
    final filtered = state.where((wb) => wb.id != id).toList();
    
    if (filtered.length == state.length) return;

    state = filtered;
    await _saveWhiteBoards();
  }
}