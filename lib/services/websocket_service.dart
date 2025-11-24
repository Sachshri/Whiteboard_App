

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:white_boarding_app/services/api_constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  Function(Map<String, dynamic>)? onMessageReceived;

  void connect(String docId, String token) {
    if (_channel != null) return;

    
    final url = '${ApiConstants.wsService}/docId/$docId/token/$token';
    debugPrint("Connecting to WS: $url");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel!.stream.listen(
        (message) {
          debugPrint("WS Received: $message");
          if (onMessageReceived != null) {
            try {
              final data = jsonDecode(message);
              onMessageReceived!(data);
            } catch (e) {
              debugPrint("WS Parse Error: $e");
            }
          }
        },
        onError: (error) => debugPrint("WS Error: $error"),
        onDone: () => debugPrint("WS Closed"),
      );
    } catch (e) {
      debugPrint("WS Connection Exception: $e");
    }
  }

  void send(Map<String, dynamic> message) {
    if (_channel != null) {
      final jsonMsg = jsonEncode(message);
      debugPrint("WS Sending: $jsonMsg");
      _channel!.sink.add(jsonMsg);
    } else {
      debugPrint("WS Not connected, cannot send.");
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}