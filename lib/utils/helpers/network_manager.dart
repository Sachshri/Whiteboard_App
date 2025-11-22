import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Define the provider globally
final networkManagerProvider = NotifierProvider<NetworkManager, ConnectivityResult>(NetworkManager.new);

class NetworkManager extends Notifier<ConnectivityResult> {
  final Connectivity _connectivity = Connectivity();

  @override
  ConnectivityResult build() {
    // 1. Initialize the stream listener when the provider is first built
    final subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });

    // 2. Dispose of the subscription automatically when the provider is destroyed
    ref.onDispose(() {
      subscription.cancel();
    });

    // 3. Set initial state (You could also do an async check here if needed)
    return ConnectivityResult.none;
  }

  /// Update network status based on the stream list
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Logic: If the list contains 'none', we are disconnected.
    // Otherwise, take the last known status.
    final newState = results.contains(ConnectivityResult.none)
        ? ConnectivityResult.none
        : results.last;

    // Update the state
    state = newState;

    // Trigger Side Effect (Toast)
    if (state == ConnectivityResult.none) {
      // Ensure your CustomLoaders doesn't rely on Get.context if you removed GetX completely
      CustomLoaders.customToast(message: 'Please check your network settings.');
    }
  }

  /// Manually check internet connectivity
  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.contains(ConnectivityResult.none)) {
        return false;
      } else {
        return true;
      }
    } on PlatformException catch (_) {
      return false;
    }
  }
}

// Mock class for the example to compile without errors
class CustomLoaders {
  static void customToast({required String message}) {
    // Your toast logic here
    print("TOAST: $message");
  }
}