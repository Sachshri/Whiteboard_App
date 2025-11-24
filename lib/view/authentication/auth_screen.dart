import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/common/widgets/buttons/gradient_elevated_button.dart';
import 'package:white_boarding_app/common/widgets/input_field/custom_text_form_field.dart';
import 'package:white_boarding_app/common/widgets/loaders/app_snack_bar.dart';
import 'package:white_boarding_app/utils/constants/text_strings.dart';
import 'package:white_boarding_app/utils/device/device_utility.dart';
import 'package:white_boarding_app/utils/validators/validators.dart';
import 'package:white_boarding_app/view/authentication/create_account_screen.dart';
import 'package:white_boarding_app/view/whiteboard/home_screen.dart';
import 'package:white_boarding_app/viewmodels/auth_viewmodel.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = DeviceUtility.getScreenWidth(context) >= 650;
    // final authState = ref.watch(authProvider);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      // appBar: authState.isAuthenticated
      //     ? AppBar(
      //         automaticallyImplyLeading: authState.isAuthenticated
      //             ? true
      //             : false,
      //       )
      //     : null,
      body: Stack(
        children: [
          // 1. BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset('assets/background.png', fit: BoxFit.cover),
          ),

          // 2. CONTENT LAYER
          Center(child: isDesktop ? const DesktopCard() : const MobileLayout()),
        ],
      ),
    );
  }
}

class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({super.key});

  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      debugPrint("--- AUTH LISTENER TRIGGERED ---");
      debugPrint("PREVIOUS isLoading: ${previous?.isLoading}");
      debugPrint("NEXT isLoading: ${next.isLoading}");
      debugPrint("NEXT Error: ${next.errorMessage}");
      if ((previous?.isLoading == true) && !next.isLoading) {
        if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
          AppSnackBar.show(context, message: next.errorMessage!, isError: true);
          next.copyWith(errorMessage: null);
        }
      }
      // 2. Handle Authentication Success
      else if (next.isAuthenticated &&
          (previous == null || !previous.isAuthenticated)) {
        AppSnackBar.show(context, message: "Welcome back!", isError: false);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    });
    // ref.listen(authProvider, (previous, next) {
    //   debugPrint("--- AUTH LISTENER TRIGGERED ---");
    //   debugPrint("PREVIOUS isLoading: ${previous?.isLoading}");
    //   debugPrint("NEXT isLoading: ${next.isLoading}");
    //   debugPrint("NEXT Error: ${next.errorMessage}");

    //   // ✅ IMPROVED: Show error whenever it appears and wasn't there before
    //   if (next.errorMessage != null &&
    //       next.errorMessage!.isNotEmpty &&
    //       previous?.errorMessage != next.errorMessage) {
    //     // Show error snackbar
    //     AppSnackBar.show(context, message: next.errorMessage!, isError: true);

    //     // Clear error after showing it
    //     Future.microtask(() {
    //       ref.read(authProvider.notifier).clearError();
    //     });
    //   }

    //   // 2. Handle Authentication Success
    //   if (next.isAuthenticated &&
    //       (previous == null || !previous.isAuthenticated)) {
    //     AppSnackBar.show(context, message: "Welcome back!", isError: false);

    //     Navigator.of(context).pushAndRemoveUntil(
    //       MaterialPageRoute(builder: (context) => const HomeScreen()),
    //       (route) => false,
    //     );
    //   }
    // });
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. LOGO
          SizedBox(
            height: 80,
            width: 80,
            child: Image.asset('assets/app_logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 24),

          // 2. LOGIN TITLE & SUBTITLE
          Text(
            TextStringsConstants.loginTitle,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TextStringsConstants.loginSubTitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          // 3. EMAIL FIELD
          CustomTextFormField(
            controller: _emailController,
            showOutlineBorder: true,
            label: "Email",
            hintText: "Enter Email",
            prefixIcon: Icons.email_outlined,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 16),

          // 4. PASSWORD FIELD (FIXED VISIBILITY)
          CustomTextFormField(
            controller: _passwordController,
            showOutlineBorder: true,
            label: "Password",
            hintText: "Enter Password",
            prefixIcon: Icons.lock_outline,
            // Logic to toggle visibility
            obscureText: !_isPasswordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            validator: Validators.validatePassword,
          ),

          const SizedBox(height: 24),

          // 5. LOGIN BUTTON
          SizedBox(
            width: double.infinity,
            height: 50,
            child: GradientElevatedButton(
              onPressed: authState.isLoading
                  ? () {}
                  : () {
                      if (authState.isAuthenticated) {
                        ref.read(authProvider.notifier).logout();
                      }
                      if (_formKey.currentState!.validate()) {
                        ref
                            .read(authProvider.notifier)
                            .login(
                              _emailController.text.trim(),
                              _passwordController.text.trim(),
                            );
                      }
                      if (authState.isAuthenticated) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // 6. CREATE ACCOUNT BUTTON
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAccountScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Create account",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 33, 149, 243),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7. GUEST BUTTON
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
              side: const BorderSide(color: Colors.blue),
            ),
            onPressed: () {
              if (authState.isAuthenticated) {
                ref.read(authProvider.notifier).logout();
              }
              ref.read(authProvider.notifier).enterAsGuest();
              if (authState.isAuthenticated) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              "Guest Access",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class DesktopCard extends ConsumerWidget {
  const DesktopCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 450,
      constraints: BoxConstraints(
        maxHeight: DeviceUtility.getScreenHeight(context) * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(54),
            blurRadius: 15,
            spreadRadius: 5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const SingleChildScrollView(
        padding: EdgeInsets.all(40.0),
        child: AuthForm(),
      ),
    );
  }
}

class MobileLayout extends StatelessWidget {
  const MobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: const AuthForm(),
        ),
      ),
    );
  }
}
