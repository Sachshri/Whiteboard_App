import 'package:flutter/material.dart';
import 'package:white_boarding_app/utils/constants/color_constants.dart'; 

class LinearGradientConstants {
  LinearGradientConstants._();

  // --- Button Gradients ---
  static const LinearGradient lightButtonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ColorConstants.lighterBlue, ColorConstants.lightBlue],
  );
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ColorConstants.lightBlue, ColorConstants.mediumBlue],
  );

  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E3A8A), 
      Color(0xFF0F172A), 
    ],
  );

  // --- Background Gradients (for specific sections or full screens) ---
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFDBEAFE), // Even lighter blue
      Color(0xFFBFDBFE), // lightestBlue
    ],
  );

  // --- BMI Trend Graph Background Gradient ---
  static const LinearGradient graphBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x103B82F6), // Very light transparent blue for top
      Colors.transparent, // Transparent for bottom
    ],
  );

  // --- Profile Card Background Gradient (example for active/selected profile) ---
  static const LinearGradient profileCardActiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEFF6FF), // Very light blue
      ColorConstants.lightestBlue,
    ],
  );
}
