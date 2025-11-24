import 'package:flutter/material.dart';

class UserCursor {
  final String userId;
  final String username;
  final Offset position;
  final Color color; // Assign a random color per user

  UserCursor({required this.userId, required this.username, required this.position, required this.color});
}