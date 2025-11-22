// lib/models/white_board_history.dart

import 'white_board.dart';

class WhiteBoardHistory {
  final List<WhiteBoard> history;
  final int currentIndex;

  WhiteBoard get currentBoard => history[currentIndex];

  WhiteBoardHistory({
    required this.history,
    required this.currentIndex,
  });
  WhiteBoardHistory copyWith({
    List<WhiteBoard>? history,
    int? currentIndex,
  }) {
    return WhiteBoardHistory(
      history: history ?? this.history,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  factory WhiteBoardHistory.initial(WhiteBoard initialBoard) {
    return WhiteBoardHistory(
      history: [initialBoard],
      currentIndex: 0,
    );
  }

  bool get canUndo => currentIndex > 0;

  bool get canRedo => currentIndex < history.length - 1;

  WhiteBoardHistory push(WhiteBoard newState) {
    final newHistory = history.sublist(0, currentIndex + 1);
    
    newHistory.add(newState);

    return WhiteBoardHistory(
      history: newHistory,
      currentIndex: newHistory.length - 1,
    );
  }

  WhiteBoardHistory undo() {
    if (!canUndo) return this;
    return WhiteBoardHistory(
      history: history,
      currentIndex: currentIndex - 1,
    );
  }

  WhiteBoardHistory redo() {
    if (!canRedo) return this;
    return WhiteBoardHistory(
      history: history,
      currentIndex: currentIndex + 1,
    );
  }
}