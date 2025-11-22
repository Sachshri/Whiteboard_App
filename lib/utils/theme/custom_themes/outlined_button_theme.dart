import 'package:flutter/material.dart';
import 'package:white_boarding_app/utils/theme/custom_themes/text_theme.dart';
import 'package:white_boarding_app/utils/constants/color_constants.dart';
import 'package:white_boarding_app/utils/constants/sizes_constants.dart';

class CustomOutlinedButtonTheme {
  CustomOutlinedButtonTheme._();
  static final outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ColorConstants.mediumBlue, // Text color is blue
      backgroundColor: ColorConstants.cardBackground, // White background for the button
      overlayColor: ColorConstants.lightBlue.withAlpha(27), // Light blue ripple effect
      side: const BorderSide(
        color: ColorConstants.mediumBlue, // Blue border
        width: 2, // Default border width
      ),
      padding: const EdgeInsets.symmetric(
        vertical: SizeConstants.buttonHeight, // Consistent vertical padding
      ),
      textStyle: CustomTextTheme.textTheme.headlineSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SizeConstants.borderRadiusLg), // Consistent border radius
      ),
      // Outlined buttons typically don't have elevation
      elevation: 0,
    ),
  );

}
