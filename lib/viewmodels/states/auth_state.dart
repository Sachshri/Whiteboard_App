import 'package:white_boarding_app/models/auth_model/app_user.dart';

// State Class
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isFirstRun; // To handle your specific first-time flow

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isFirstRun = true,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? errorMessage,
    bool? isFirstRun,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Reset error if not provided
      isFirstRun: isFirstRun ?? this.isFirstRun,
    );
  }
}