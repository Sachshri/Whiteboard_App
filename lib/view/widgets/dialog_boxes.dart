import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/white_board.dart';
import 'package:white_boarding_app/viewmodels/active_board_viewmodel.dart';
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
            TextButton(onPressed: ()=>{Navigator.of(context).pop()}, child: Text("Cancel"))
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
                // 1. Delete the board from the global list
                ref
                    .read(whiteBoardListProvider.notifier)
                    .deleteBoard(whiteBoard.id);
                
                // 2. Close the dialog
                Navigator.of(context).pop(); 
                
                // 3. Close the WhiteBoardScreen, since the board no longer exists
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
                    // **FIXED LOGIC**: Use local notifier for immediate update
                    localNotifier.pushNewState(updatedBoard);
                  } else {
                    // Fallback (used by HomeScreen only)
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
}
