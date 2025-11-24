class Validators {
  Validators._();
  static String? validateEmail(String? email) {
    if (email == null) {
      return "Email Required";
    }
    RegExp regex = RegExp(r'^(?!\.)[A-Za-z0-9._%+-]+@(?!-)(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}$');
    if (!regex.hasMatch(email)) {
      return "Invalid Email Address!";
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Password is required";
    }
    //min password length

    if (value.length < 8) {
      return "Password must be atleast 8 character long";
    }
    return null;
  }
  static String? validateConfirmPassword(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return "Confirm Password is required";
    }
    if (password != confirmPassword) {
      return "Passwords do not match";
    }
    return null;
  }

  static String? validateEmptyText(String fieldName, String? value) {
    if (value == null || value.isEmpty) {
      return "$fieldName is required";
    }
    return null;
  }

}
