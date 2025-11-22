import 'package:flutter/material.dart';
import 'package:white_boarding_app/utils/constants/color_constants.dart';
import 'package:white_boarding_app/utils/constants/sizes_constants.dart';

class CustomElevatedButtonTheme {
  CustomElevatedButtonTheme._();

  

  static final elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: SizeConstants.buttonElevation, 
      backgroundColor: ColorConstants.mediumBlue, 
      foregroundColor: ColorConstants.whiteText, 
      
      disabledBackgroundColor: ColorConstants.secondaryText.withAlpha(127),
      disabledForegroundColor: ColorConstants.whiteText.withAlpha(127),
      side: BorderSide.none, 
      padding: const EdgeInsets.symmetric(
        vertical: SizeConstants.buttonHeight, 
      ),
      textStyle:  const TextStyle().copyWith(
      fontSize: 20,
      fontFamily: "Montserrat",
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SizeConstants.borderRadiusLg), 
      ),
    ),
  );
}