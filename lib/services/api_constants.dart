

import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  
  ApiConstants._();

  static String get _host {
    if (kIsWeb) return 'localhost'; 
    if (Platform.isAndroid) return '10.0.2.2'; 
    return 'localhost'; 
  }

  static String get baseUrl => 'http://$_host:80'; 
  
  static String get authService => '$baseUrl/auth';
  static String get docService => '$baseUrl/document';
  
  static String get wsBaseUrl => 'ws://$_host:80'; 
  static String get wsService => '$wsBaseUrl/updates/ws';
}