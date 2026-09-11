// LAB 5 — Form validators
// Every TextFormField in sign in / sign up / profile dialogs uses these,
// so the rules live in ONE place instead of being copy-pasted per screen.
// Each function returns null when the value is valid, or an error message.

class Validators {
  Validators._(); // not meant to be instantiated

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    if (!RegExp(r"^[a-zA-ZñÑ .'-]+$").hasMatch(v)) return 'Letters only';
    return null;
  }

  static String? age(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Required';
    final age = int.tryParse(v);
    if (age == null) return 'Numbers only';
    if (age < 13 || age > 120) return 'Must be 13–120';
    return null;
  }

  /// Philippine mobile format: 09XXXXXXXXX or +639XXXXXXXXX.
  static String? contactNo(String? value) {
    final v = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (v.isEmpty) return 'Contact number is required';
    if (!RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(v)) {
      return 'Use 09XXXXXXXXX or +639XXXXXXXXX';
    }
    return null;
  }

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please choose a username';
    if (v.length < 3) return 'At least 3 characters';
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(v)) {
      return 'Letters, numbers, dot and underscore only';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // ---------- Password rules ----------
  // Shown live as a checklist under the password field (see
  // widgets/password_requirements.dart) AND enforced on submit.
  static const Map<String, String> passwordRules = {
    'length': 'At least 8 characters',
    'upper': 'One uppercase letter (A–Z)',
    'lower': 'One lowercase letter (a–z)',
    'number': 'One number (0–9)',
    'special': 'One special character (!@#\$...)',
  };

  static Map<String, bool> checkPassword(String value) => {
    'length': value.length >= 8,
    'upper': RegExp(r'[A-Z]').hasMatch(value),
    'lower': RegExp(r'[a-z]').hasMatch(value),
    'number': RegExp(r'[0-9]').hasMatch(value),
    'special': RegExp(r'[^A-Za-z0-9]').hasMatch(value),
  };

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    final failed = checkPassword(v).entries.where((e) => !e.value);
    if (failed.isNotEmpty) return passwordRules[failed.first.key];
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      if (value == null || value.isEmpty) return 'Please confirm your password';
      if (value != original()) return 'Passwords do not match';
      return null;
    };
  }
}
