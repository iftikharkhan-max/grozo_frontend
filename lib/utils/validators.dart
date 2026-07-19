class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validateCNIC(String? value) {
    if (value == null || value.isEmpty) return 'CNIC is required';
    if (!RegExp(r'^\d{5}-\d{7}-\d{1}$').hasMatch(value)) {
      return 'Format must be NNNNN-NNNNNNN-N';
    }
    return null;
  }

  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) return 'Mobile is required';
    if (!RegExp(r'^\d{4}-\d{7}$').hasMatch(value)) {
      return 'Format must be NNNN-NNNNNNN';
    }
    return null;
  }
}