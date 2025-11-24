import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart'; 
import 'package:white_boarding_app/models/auth_model/app_user.dart';
import 'package:white_boarding_app/utils/helpers/app_helper.dart';

class AuthRepository {
  String get baseUrl {
    if (kIsWeb) return 'http://localhost:80';
    if (Platform.isAndroid) return 'http://10.0.2.2:80';
    return 'http://localhost:80';
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _authTokenKey = 'auth_token';
  static const _authUserKey = 'auth_user_data';
  Future<AppUser?> getCurrentUser() async {
    try {
      final token = await _storage.read(key: _authTokenKey);
      if (token == null || JwtDecoder.isExpired(token)) {
        await logout();
        return null;
      }
      return _userFromToken(token);
    } catch (e) {
      await logout();
      return null;
    }
  }

  Future<AppUser> login(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/login');
      debugPrint("POST Login: $uri");
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      debugPrint("Login Response Code: ${response.statusCode}");
      debugPrint("Login Response Body: ${response.body}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['access_token'] ?? '';
        if (token.isEmpty) throw Exception("No access_token received");
        final user = _userFromToken(token);
        await _storage.write(key: _authTokenKey, value: token);
        await _storage.write(
          key: _authUserKey,
          value: jsonEncode(user.toJson()),
        );
        return user;
      } else {
        throw _parseHttpError(response);
      }
    } catch (e) {
      throw Exception(_cleanError(e));
    }
  }
  Future<AppUser> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/register');
      debugPrint("POST Register: $uri");
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );
      debugPrint("Register Response Code: ${response.statusCode}");
      debugPrint("Register Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AppUser(
          id: 'temp_id',
          name: username,
          email: email,
          token: null,
        );
      } else {
        throw _parseHttpError(response);
      }
    } catch (e) {
      throw _cleanError(e);
    }
  } 
  Future<void> logout() async {
    await _storage.delete(key: _authTokenKey);
    await _storage.delete(key: _authUserKey);
  } 
  AppUser _userFromToken(String token) {
    try {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      return AppUser(
        id: decodedToken['user_id'] ?? decodedToken['user_id'] ?? '',
        name: decodedToken['username'] ?? 'User',
        email: decodedToken['email'] ?? '',
        token: token,
      );
    } catch (e) {
      throw AppFailure("Invalid Token Data");
    }
  }
  AppFailure _parseHttpError(http.Response response) {
    try {
      
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('error')) {
        return AppFailure(data['error']);
      }
      if (data is Map && data.containsKey('message')) {
        return AppFailure(data['message']);
      }
    } catch (_) {} 
    switch (response.statusCode) {
      case 400:
        return AppFailure("Invalid request. Please check your inputs.");
      case 401:
        return AppFailure("Incorrect credentials.");
      case 403:
        return AppFailure("You do not have permission to perform this action.");
      case 404:
        return AppFailure("Invalid Credentials or Resources not found.");
      case 409:
        return AppFailure("User already exists.");
      case 500:
        return AppFailure("Internal Server Error. Please try again later.");
      default:
        return AppFailure(
          "Unknown error occurred (Code: ${response.statusCode})",
        );
    }
  }
  AppFailure _cleanError(dynamic e) {
    if (e is AppFailure) return e;
    if (e is SocketException) return AppFailure("No Internet Connection.");
    if (e is TimeoutException) return AppFailure("Server request timed out.");
    if (e is FormatException) return AppFailure("Bad response format.");
    return AppFailure("Something went wrong.");
  }
}
