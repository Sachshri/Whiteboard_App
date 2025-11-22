import 'package:flutter/material.dart';
import 'package:white_boarding_app/utils/constants/color_constants.dart';

class CustomChipTheme {
  CustomChipTheme._();

  static final chipTheme = ChipThemeData(
    disabledColor: Colors.grey.withAlpha(102),
    labelStyle: TextStyle(
      color: Colors.black,
    ),
    selectedColor: ColorConstants.primaryBlue,
    padding: const EdgeInsets.symmetric(horizontal: 12,vertical: 12),
    checkmarkColor: Colors.white,
  );
}
