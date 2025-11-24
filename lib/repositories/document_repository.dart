// lib/repositories/document_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:white_boarding_app/services/api_constants.dart';
import 'package:white_boarding_app/models/whiteboard_models/white_board.dart';

class DocumentRepository {
  
  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Ensure "Bearer " prefix
    };
  }

  // GET /document/all
// Update the getAllDocuments method

  Future<List<WhiteBoard>> getAllDocuments(String token) async {
    final uri = Uri.parse('${ApiConstants.docService}/all');
    
    try {
      final response = await http.get(uri, headers: _getHeaders(token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<WhiteBoard> documents = [];

        if (data['ownedDocuments'] != null) {
          documents.addAll((data['ownedDocuments'] as List? ?? [])
              .map((e) {
                // FORCE isSynced: true because it came from server
                var wb = WhiteBoard.fromJson(e);
                return wb.copyWith(isSynced: true); 
              }));
        }
        
        if (data['sharedDocuments'] != null) {
          documents.addAll((data['sharedDocuments'] as List? ?? [])
              .map((e) {
                // FORCE isSynced: true for shared docs too
                var wb = WhiteBoard.fromJson(e);
                return wb.copyWith(isSynced: true);
              }));
        }
        
        return documents;
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("GetAllDocuments Error: $e");
      rethrow;
    }
  }
  // POST /document/create
  Future<String> createDocument(String token) async {
    final uri = Uri.parse('${ApiConstants.docService}/create');
    
    try {
      final response = await http.post(uri, headers: _getHeaders(token));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id']; 
      } else {
        throw Exception('Failed to create: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("CreateDocument Error: $e");
      throw Exception("Connection failed. Is the server running?");
    }
  }

  // POST /document/delete
  Future<bool> deleteDocument(String token, String docId) async {
    final uri = Uri.parse('${ApiConstants.docService}/delete');
    
    try {
      final response = await http.post(
        uri,
        headers: _getHeaders(token),
        body: jsonEncode({"documentId": docId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  // Search users by email/username
// Search users by email/username
  Future<List<Map<String, dynamic>>> searchUsers(String token, String query) async {
    // 1. Sanitize the query
    final cleanQuery = query.trim().toLowerCase();
    
    // 2. Build URI (Make sure ApiConstants.authService is correct, e.g., 'http://10.0.2.2:8080')
    final uri = Uri.parse('${ApiConstants.authService}/users?q=$cleanQuery');
    
    debugPrint("🚀 SEARCH REQUEST: $uri");

    try {
      final response = await http.get(uri, headers: _getHeaders(token));
      
      // 3. DEBUG PRINT: See exactly what the server replies
      debugPrint("📥 SEARCH RESPONSE [${response.statusCode}]: ${response.body}");

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);

        // CASE A: Backend returns a raw List -> [...]
        if (decodedData is List) {
          return List<Map<String, dynamic>>.from(decodedData);
        } 
        // CASE B: Backend returns an Object with a key -> { "users": [...] }
        else if (decodedData is Map && decodedData.containsKey('users')) {
          return List<Map<String, dynamic>>.from(decodedData['users']);
        }
        // CASE C: Backend returns an Object with "data" -> { "data": [...] }
        else if (decodedData is Map && decodedData.containsKey('data')) {
           return List<Map<String, dynamic>>.from(decodedData['data']);
        }
        
        debugPrint("⚠️ WARNING: Unexpected JSON format. Expected List or {users:[]}");
        return [];
      } else {
        debugPrint("❌ Server Error: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ SEARCH EXCEPTION: $e");
      return [];
    }
  }

  Future<bool> shareDocument(String token, String docId, String collaboratorId, String accessType) async {
    final uri = Uri.parse('${ApiConstants.docService}/share');
    try {
      final response = await http.post(
        uri,
        headers: _getHeaders(token),
        body: jsonEncode({
          "documentId": docId,
          "collaboratorUserId": collaboratorId,
          "accessType": accessType,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Share Document Error: $e");
      return false;
    }
  }
}