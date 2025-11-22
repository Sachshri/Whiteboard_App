import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';
import 'package:white_boarding_app/utils/helpers/helpers.dart';
import 'package:white_boarding_app/viewmodels/active_board_viewmodel.dart';
import 'package:white_boarding_app/viewmodels/tool_viewmodel.dart';
import 'package:white_boarding_app/viewmodels/white_board_viewmodel.dart';

class DialogBoxes {
  DialogBoxes._();
  static Future<void> showWarningDialog(
    BuildContext context, {
    required String message,
    String buttonText = 'OK',
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.amber),
              const SizedBox(width: 8),
              const Text('Warning'),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onConfirm != null) onConfirm();
              },
              child: Text(
                buttonText,
                style: const TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () => {Navigator.of(context).pop()},
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  static void showTitleEditDialog(
    BuildContext context,
    WidgetRef ref,
    WhiteBoard whiteBoard,
    bool popNeeded, {
    ActiveBoardNotifier? localNotifier,
  }) {
    final controller = TextEditingController(text: whiteBoard.title);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename White Board'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter new title"),
          ),
          actions: [
            IconButton(
              onPressed: () {
                ref
                    .read(whiteBoardListProvider.notifier)
                    .deleteBoard(whiteBoard.id);

                Navigator.of(context).pop();

                if (popNeeded) {
                  Navigator.of(context).pop();
                }
              },
              icon: Icon(Icons.delete),
              color: Colors.red,
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  final updatedBoard = whiteBoard.copyWith(
                    title: controller.text,
                  );

                  if (localNotifier != null) {
                    localNotifier.pushNewState(updatedBoard);
                  } else {
                    ref
                        .read(whiteBoardListProvider.notifier)
                        .updateWhiteBoard(updatedBoard);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }
  static void showColorPicker(BuildContext context, WidgetRef ref, String propertyToUpdate) {
  final options = ref.read(toolOptionsProvider);
  final optionsNotifier = ref.read(toolOptionsProvider.notifier);

  final currentColor = (propertyToUpdate == 'color')
      ? Helpers.colorFromHex(options.color)
      : Helpers.colorFromHex(options.fillColor);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      Color pickedColor = currentColor;
      return AlertDialog(
        title: Text('Select ${propertyToUpdate == 'color' ? 'Stroke' : 'Fill'} Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) => pickedColor = color,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
           Column(
            children: [
              Text("Click the Apply Button to select color",style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600,color: Colors.red)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: Colors.blueAccent
              ),
              onPressed: () {
                final hexColor = Helpers.colorToHex(pickedColor);
                if (propertyToUpdate == 'color') {
                  optionsNotifier.state = options.copyWith(color: hexColor);
                } else {
                  optionsNotifier.state = options.copyWith(fillColor: hexColor);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Apply',style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600,color: Colors.white)),
            ),
          ),
        ],
      );
    },
  );
}

static void showSelectedObjectColorPicker(BuildContext context, WidgetRef ref, WhiteBoard board, String propertyToUpdate) {
  final notifier = ref.read(activeBoardHistoryProvider(board).notifier);
  final Color defaultColor = (propertyToUpdate == 'color') ? Colors.black : Colors.white;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      Color pickedColor = defaultColor;
      return AlertDialog(
        title: Text('Update ${propertyToUpdate == 'color' ? 'Stroke' : 'Fill'} Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: defaultColor,
            onColorChanged: (color) => pickedColor = color,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
           Column(
            children: [
              Text("Click the Apply Button to select color",style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600,color: Colors.red)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: Colors.blueAccent
              ),
              child: const Text('Apply',style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600,color: Colors.white)),
              onPressed: () {
                final hexColor = Helpers.colorToHex(pickedColor);
                if (propertyToUpdate == 'color') {
                  notifier.updateSelectedObjectsAttributes(board, strokeColor: hexColor);
                } else {
                  notifier.updateSelectedObjectsAttributes(board, fillColor: hexColor);
                }
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      );
    },
  );
}

static void showStrokeWidthSelector(BuildContext context, WidgetRef ref) {
  final provider = ref.read(toolOptionsProvider.notifier);
  final options = provider.state;
  const List<double> widths = [2.0, 4.0, 6.0, 8.0, 12.0, 16.0];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext bc) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Stroke Width', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: widths.map((width) {
                  final isSelected = options.strokeWidth == width;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: InkWell(
                      onTap: () {
                        provider.state = options.copyWith(strokeWidth: width);
                        Navigator.pop(bc);
                      },
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF55B8B9).withAlpha(54) : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: const Color(0xFF55B8B9), width: 2) : null,
                              ),
                              child: Center(
                                child: Container(
                                  width: width,
                                  height: width,
                                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Text('Current', style: TextStyle(fontSize: 10, color: Color(0xFF55B8B9))),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

static void showEraserSizeSelector(BuildContext context, WidgetRef ref) {
  final provider = ref.read(toolOptionsProvider.notifier);
  final options = provider.state;
  const List<double> sizes = [8.0, 12.0, 20.0, 30.0, 40.0, 50.0];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext bc) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Eraser Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: sizes.map((size) {
                  final isSelected = options.eraserSize == size;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: InkWell(
                      onTap: () {
                        provider.state = options.copyWith(eraserSize: size);
                        Navigator.pop(bc);
                      },
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF55B8B9).withAlpha(54) : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: const Color(0xFF55B8B9), width: 2) : null,
                              ),
                              child: Center(
                                child: Container(
                                  width: size / 1.5,
                                  height: size / 1.5,
                                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Text('Current', style: TextStyle(fontSize: 10, color: Color(0xFF55B8B9))),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

}
