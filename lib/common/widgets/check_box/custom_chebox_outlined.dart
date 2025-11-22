import 'package:flutter/material.dart';
import 'package:white_boarding_app/utils/constants/color_constants.dart';

class CustomCheckBoxOutlined extends StatelessWidget {
  const CustomCheckBoxOutlined({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final Function(bool?) onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        border: BoxBorder.all(color: ColorConstants.lightBlue, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Checkbox(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.transparent,
        focusColor: Colors.transparent,
        checkColor: ColorConstants.lightBlue,

        side: BorderSide(color: Colors.transparent),
      ),
    );
  }
}
