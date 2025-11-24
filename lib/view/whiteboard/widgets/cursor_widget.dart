import 'package:flutter/material.dart';
import 'package:white_boarding_app/models/whiteboard_models/user_cursor_model.dart';

class RemoteCursorsWidget extends StatelessWidget {
  final Map<String, UserCursor> cursors;

  const RemoteCursorsWidget({super.key, required this.cursors});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: cursors.values.map((cursor) {
        return Positioned(
          left: cursor.position.dx,
          top: cursor.position.dy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.near_me, size: 18, color: cursor.color),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: cursor.color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cursor.username,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}