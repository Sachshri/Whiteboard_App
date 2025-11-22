import 'dart:ui';

class Helpers {
  Helpers._();
  static String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2, 8)}';
}

static Color colorFromHex(String hexColor) {
  hexColor = hexColor.replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";
  }
  return Color(int.parse(hexColor, radix: 16));
}
}