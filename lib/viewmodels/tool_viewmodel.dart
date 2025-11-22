import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/whiteboard_models/ui_state.dart';

final toolStateProvider = StateNotifierProvider<ToolStateNotifier, ToolType>((ref) {
  return ToolStateNotifier();
});

final toolOptionsProvider = StateProvider<ToolOptions>((ref) {
  return ToolOptions();
});

class ToolStateNotifier extends StateNotifier<ToolType> {
  ToolStateNotifier() : super(ToolType.selection);

  void selectTool(ToolType newTool) {
    state = newTool;
  }
}
