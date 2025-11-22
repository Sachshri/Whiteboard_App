import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/utils/theme/theme.dart';
import 'package:white_boarding_app/view/authentication/auth_screen.dart';
import 'package:white_boarding_app/view/whiteboard/home_screen.dart';
import 'package:white_boarding_app/viewmodels/auth_viewmodel.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Whiteboard App',
      theme: CustomAppTheme.appTheme,
      debugShowCheckedModeBanner: false,
      home: authState.isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : (authState.isAuthenticated ? const HomeScreen() : const AuthScreen()),
    );
  }
}