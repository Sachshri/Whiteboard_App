import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/models/auth_model/app_user.dart';
import 'package:white_boarding_app/repositories/auth_repository.dart';
import 'package:white_boarding_app/utils/helpers/network_manager.dart';
import 'package:white_boarding_app/viewmodels/states/auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthRepository(), ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref; // Keep a reference to Ref

  AuthNotifier(this._repository, this._ref) : super(AuthState()) {
    _checkSession();
  }
  // Helper to check internet using NetworkManager
  Future<bool> _hasInternetConnection() async {
    final isConnected = await _ref
        .read(networkManagerProvider.notifier)
        .isConnected();
    if (!isConnected) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "No Internet Connection. Please check your settings.",
      );
      return false;
    }
    return true;
  }

  Future<void> _checkSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _repository.getCurrentUser();
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, user: null);
    }
  }

  Future<void> login(String email, String password) async {
    if (!await _hasInternetConnection()) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.login(email, password);
      state = state.copyWith(isLoading: false, user: user, errorMessage: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      debugPrint("Error::\n\n\n\n ${e.toString()}");
    }
  }

  Future<void> register(String username, String email, String password) async {
    if (!await _hasInternetConnection()) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.register(username, email, password);
      state = state.copyWith(isLoading: false, errorMessage: null);
    } catch (e) {
      final cleanMessage = e.toString();
      debugPrint("Register Error: $cleanMessage");
      state = state.copyWith(isLoading: false, errorMessage: cleanMessage);
    }
  }

  // Guest Login - Does not hit backend, creates a temporary session in memory
  void enterAsGuest() {
    final guestUser = AppUser(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Guest',
      email: 'guest@local',
      token: 'guest_token',
    );
    state = state.copyWith(user: guestUser, errorMessage: null);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = state.copyWith(user: null);
  }

  // Helper to clear error manually if needed by UI
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
