import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/repositories/document_repository.dart';
import 'package:white_boarding_app/viewmodels/auth_viewmodel.dart';
import 'package:white_boarding_app/common/widgets/input_field/custom_text_form_field.dart';

class ShareBoardDialog extends ConsumerStatefulWidget {
  final String documentId;
  const ShareBoardDialog({super.key, required this.documentId});

  @override
  ConsumerState<ShareBoardDialog> createState() => _ShareBoardDialogState();
}

class _ShareBoardDialogState extends ConsumerState<ShareBoardDialog> {
  final TextEditingController _searchController = TextEditingController();
  final DocumentRepository _repo = DocumentRepository();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _statusMessage;

  void _search() async {
    if (_searchController.text.trim().isEmpty) return;
    
    // Close keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _searchResults = [];
    });

    final token = ref.read(authProvider).user?.token ?? '';
    final results = await _repo.searchUsers(token, _searchController.text.trim());
    
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
        if (results.isEmpty) {
          _statusMessage = "No users found with that email.";
        }
      });
    }
  }

  void _share(String userId, String username) async {
    setState(() => _isLoading = true);
    
    final token = ref.read(authProvider).user?.token ?? '';
    // Defaulting accessType to "editor" for full collaboration
    final success = await _repo.shareDocument(token, widget.documentId, userId, "editor");
    
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context); // Close dialog
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Success! Board shared with $username"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to share. Try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Collaborate"),
      content: SizedBox(
        width: 400, // Fixed width for better desktop appearance
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Search for users by email to grant them access to this board.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: CustomTextFormField(
                    controller: _searchController,
                    hintText: "user@example.com",
                    label: "Email Address",
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF55B8B9),
                    padding: const EdgeInsets.all(14),
                    shape: const CircleBorder(),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_statusMessage!, style: const TextStyle(color: Colors.red)),
              ),

            if (_searchResults.isNotEmpty) ...[
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Search Results:", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 5),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: Text((user['username']?[0] ?? 'U').toUpperCase()),
                      ),
                      title: Text(user['username'] ?? 'Unknown'),
                      subtitle: Text(user['email'] ?? ''),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF55B8B9),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _share(user['id'], user['username']),
                        child: const Text("Invite"),
                      ),
                    );
                  },
                ),
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        )
      ],
    );
  }
}