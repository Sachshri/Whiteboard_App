import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/viewmodels/white_board_viewmodel.dart';
import 'package:white_boarding_app/view/whiteboard/widgets/share_board_dialog.dart';
import 'package:white_boarding_app/utils/helpers/dialog_boxes.dart';

class BoardSelectionDialog extends ConsumerWidget {
  const BoardSelectionDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final whiteBoards = ref.watch(whiteBoardListProvider);

    return AlertDialog(
      title: const Text("Select Board to Share"),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: whiteBoards.isEmpty
            ? const Center(child: Text("No boards available."))
            : ListView.builder(
                itemCount: whiteBoards.length,
                itemBuilder: (context, index) {
                  final board = whiteBoards[index];
                  return ListTile(
                    leading: Icon(
                      board.isSynced ? Icons.cloud_done : Icons.cloud_off,
                      color: board.isSynced ? Colors.blue : Colors.grey,
                    ),
                    title: Text(board.title),
                    subtitle: Text(board.isSynced ? "Synced" : "Local only"),
                    onTap: () async {
                      // Close selection dialog
                      Navigator.pop(context);

                      if (board.isSynced) {
                        // Directly show share dialog
                        showDialog(
                          context: context,
                          builder: (context) => ShareBoardDialog(documentId: board.id),
                        );
                      } else {
                        // Ask to sync first
                         DialogBoxes.showWarningDialog(
                          context, 
                          message: "This board must be synced to the cloud before sharing.",
                          onConfirm: () async {
                             Navigator.pop(context); // Close warning
                             // Trigger Sync logic here if needed, 
                             // or tell user to press Sync button on Home
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Please sync the board using the Sync button first."))
                             );
                          }
                        );
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        )
      ],
    );
  }
}