import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToolType {
  selection,
  pan,
  pencil,
  eraser,
  rectangle,
  circle,
  arrow,
  line,
  text,
  image,
}

enum SelectionMode {
  none,
  moving,
  resizingTl, // Top-Left handle
  resizingTr, // Top-Right handle
  resizingBl, // Bottom-Left handle
  resizingBr, // Bottom-Right handle
}
enum EraserMode {
  pixel, 
  stroke, 
}

class ToolOptions {
  double strokeWidth;
  String color;
  String fillColor;
  double opacity;
  EraserMode eraserMode;
  double eraserSize; 

  ToolOptions({
    this.strokeWidth = 3.0,
    this.color = '#000000',
    this.fillColor = '#FFFFFF',
    this.opacity = 1.0,
    this.eraserMode = EraserMode.pixel, 
    this.eraserSize = 10.0,
  });

  ToolOptions copyWith({
    double? strokeWidth,
    String? color,
    String? fillColor,
    double? opacity,
    EraserMode? eraserMode,
    double? eraserSize, 
  }) {
    return ToolOptions(
      strokeWidth: strokeWidth ?? this.strokeWidth,
      color: color ?? this.color,
      fillColor: fillColor ?? this.fillColor,
      opacity: opacity ?? this.opacity,
      eraserMode: eraserMode ?? this.eraserMode,
      eraserSize: eraserSize ?? this.eraserSize, 
    );
  }
}

class TextEditingState {
  final bool isVisible;
  final Offset position;
  final String text;
  final double fontSize;
  final String color;

  TextEditingState({
    this.isVisible = false,
    this.position = Offset.zero,
    this.text = '',
    this.fontSize = 24.0,
    this.color = '#000000',
  });

  TextEditingState copyWith({
    bool? isVisible,
    Offset? position,
    String? text,
    double? fontSize,
    String? color,
  }) {
    return TextEditingState(
      isVisible: isVisible ?? this.isVisible,
      position: position ?? this.position,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
    );
  }
}
final textEditingStateProvider = StateProvider<TextEditingState>((ref) {
  return TextEditingState();
});