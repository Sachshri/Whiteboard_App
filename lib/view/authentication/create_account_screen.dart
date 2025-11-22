import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:white_boarding_app/common/widgets/buttons/gradient_elevated_button.dart';
import 'package:white_boarding_app/common/widgets/input_field/custom_text_form_field.dart';
import 'package:white_boarding_app/common/widgets/loaders/app_snack_bar.dart';
import 'package:white_boarding_app/utils/device/device_utility.dart';
import 'package:white_boarding_app/viewmodels/auth_viewmodel.dart';

class CreateAccountScreen extends ConsumerWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = DeviceUtility.getScreenWidth(context) >= 650;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. CONTENT LAYER
          Center(
            child: isDesktop ? const DesktopCard() : const MobileLayout(),
          ),
        ],
      ),
    );
  }
}

class SignUpForm extends ConsumerStatefulWidget {
  const SignUpForm({super.key});

  @override
  ConsumerState<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      // 1. Handle Errors
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
         AppSnackBar.show(context, message: next.errorMessage!, isError: true);
         ref.read(authProvider.notifier).clearError();
      }

      // 2. Handle Success (Registration)
      // Assuming registration sets loading=false and error=null, but keeps user=null (waiting for login)
      if (!next.isLoading && next.errorMessage == null && previous!.isLoading) {
         AppSnackBar.show(context, message: "Account created! Please Login.", isError: false);
         Navigator.pop(context);
      }
    });

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
            child: Image.asset(
              'assets/app_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),

          // 2. TITLE & SUBTITLE
          Text(
            "Create Account",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Join us and start your journey",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // 3. FORM FIELDS

          // Username
          CustomTextFormField(
            controller: _usernameController,
            showOutlineBorder: true,
            label: "Username",
            hintText: "Enter Username",
            prefixIcon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Username is required';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          CustomTextFormField(
            controller: _emailController,
            showOutlineBorder: true,
            label: "Email",
            hintText: "Enter Email",
            prefixIcon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Email is required';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          CustomTextFormField(
            controller: _passwordController,
            showOutlineBorder: true,
            label: "Password",
            hintText: "Create a password",
            prefixIcon: Icons.lock_outline,
            suffixIcon: const Icon(Icons.visibility_off_outlined),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 6) return 'Password must be at least 6 chars';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password
          CustomTextFormField(
            controller: _confirmPasswordController,
            showOutlineBorder: true,
            label: "Confirm Password",
            hintText: "Re-enter password",
            prefixIcon: Icons.lock_outline,
            suffixIcon: const Icon(Icons.visibility_off_outlined),
            obscureText: true,
            validator: (value) {
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),

          const SizedBox(height: 24),

          // 4. SIGN UP BUTTON
          SizedBox(
            width: double.infinity,
            height: 50,
            child: GradientElevatedButton(
              onPressed: authState.isLoading
                  ? (){}
                  : () {
                      if (_formKey.currentState!.validate()) {
                        ref.read(authProvider.notifier).register(
                              _usernameController.text.trim(),
                              _emailController.text.trim(),
                              _passwordController.text.trim(),
                            );
                      }
                    },
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      "Sign Up",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. LOGIN REDIRECT
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Login",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ],
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
        maxHeight: DeviceUtility.getScreenHeight(context) * 0.95,
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
        child: SignUpForm(),
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
          child: const SignUpForm(),
        ),
      ),
    );
  }
}