import 'package:flutter/material.dart';
import 'package:white_boarding_app/utils/constants/linear_gradient_constants.dart';
import 'package:white_boarding_app/utils/constants/sizes_constants.dart';

class GradientElevatedButton extends StatelessWidget {
  const GradientElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = LinearGradientConstants.lightButtonGradient, 
    this.width,
    this.height,
    this.borderRadius,
  });

  final VoidCallback onPressed;
  final Widget child;
  final LinearGradient gradient;
  final double? width;
  final double? borderRadius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height:
          height ??
          SizeConstants.buttonHeight + 35,   
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(
          borderRadius ?? SizeConstants.borderRadiusLg,
        ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(

          backgroundColor:
              Colors.transparent, 
          shadowColor:
              Colors.transparent, 
        ),
        child: child,
      ),
    );
  }
}
