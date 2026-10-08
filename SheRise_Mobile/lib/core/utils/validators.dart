class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (value.length < 10) return 'Enter a valid 10-digit phone number';
    final regex = RegExp(r'^[0-9]{10,}$');
    if (!regex.hasMatch(value)) return 'Enter only digits';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.isEmpty) return 'OTP is required';
    if (value.length != 6) return 'OTP must be 6 digits';
    final regex = RegExp(r'^[0-9]{6}$');
    if (!regex.hasMatch(value)) return 'Enter only digits';
    return null;
  }

  static String? address(String? value) {
    if (value == null || value.isEmpty) return 'Address is required';
    if (value.length < 5) return 'Address is too short';
    return null;
  }
}
