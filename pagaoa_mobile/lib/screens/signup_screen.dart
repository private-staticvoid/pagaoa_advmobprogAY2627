// Sign up screen (Lab 5 — Enhancement 2)
// Fields required by the handout (named like dummyjson.com/users):
//   fName -> firstName, lName -> lastName, age, contactNo -> phone,
//   username, emailAddress -> email, password (with validation)
//
// Backend toggle:
//   Firebase  (default) -> REAL account: FirebaseAuth + Firestore profile,
//                          then goes straight to /home (already signed in).
//   DummyJSON           -> POST /users/add, which is only SIMULATED, so we
//                          explain that and send the user back to sign in.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/login_type.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../utils/auth_errors.dart';
import '../utils/validators.dart';
import '../widgets/password_field.dart';
import '../widgets/password_requirements.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _userService = UserService();

  LoginType _backend = LoginType.firebase;
  String _gender = 'female';
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in [
      _firstNameController,
      _lastNameController,
      _ageController,
      _contactController,
      _usernameController,
      _emailController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final age = int.parse(_ageController.text.trim());
    final contactNo = _contactController.text.replaceAll(RegExp(r'[\s-]'), '');
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_backend == LoginType.firebase) {
        await _userService.registerWithFirebase(
          firstName: firstName,
          lastName: lastName,
          age: age,
          contactNo: contactNo,
          username: username,
          email: email,
          password: password,
          gender: _gender,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome, $firstName! Account created.')),
        );
        // createUserWithEmailAndPassword also signs the user in.
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        final result = await _userService.registerUser(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          password: password,
          gender: _gender,
          age: age,
          phone: contactNo,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        await _showDummyJsonNotice(result);
        if (!mounted) return;
        Navigator.pop(context); // back to sign in
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign up failed: ${friendlyAuthError(e)}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _showDummyJsonNotice(Map<String, dynamic> result) {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('DummyJSON responded'),
        content: Text(
          'DummyJSON returned new user #${result['id']} '
          '("${result['username']}"). But it is a mock API, so this account '
          'is NOT saved and cannot log in.\n\n'
          'Choose "Firebase" on this screen to create a real account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<LoginType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: LoginType.firebase,
                      label: Text('Firebase'),
                      icon: Icon(Icons.local_fire_department_outlined),
                    ),
                    ButtonSegment(
                      value: LoginType.dummyJson,
                      label: Text('DummyJSON'),
                      icon: Icon(Icons.cloud_outlined),
                    ),
                  ],
                  selected: {_backend},
                  onSelectionChanged: (s) => setState(() => _backend = s.first),
                ),
                SizedBox(height: 8.h),
                Text(
                  _backend == LoginType.firebase
                      ? 'Creates a real account you can log in with.'
                      : 'Simulated only — DummyJSON will not save it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 20.h),

                _sectionLabel('Personal information'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                        validator: Validators.name,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                        validator: Validators.name,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110.w,
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake_outlined, size: 20.sp),
                        ),
                        validator: Validators.age,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_outlined, size: 20.sp),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                        ],
                        onChanged: (v) =>
                            setState(() => _gender = v ?? 'female'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Contact No.',
                    hintText: '09XXXXXXXXX',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20.sp),
                  ),
                  validator: Validators.contactNo,
                ),
                SizedBox(height: 24.h),

                _sectionLabel('Account'),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline, size: 20.sp),
                  ),
                  validator: Validators.username,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined, size: 20.sp),
                  ),
                  validator: Validators.email,
                ),
                SizedBox(height: 16.h),
                PasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                ),
                PasswordRequirements(controller: _passwordController),
                SizedBox(height: 16.h),
                PasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  textInputAction: TextInputAction.done,
                  validator: Validators.confirmPassword(
                    () => _passwordController.text,
                  ),
                ),
                SizedBox(height: 28.h),

                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? SizedBox(
                          height: 20.h,
                          width: 20.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.black87),
                          ),
                        )
                      : Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                SizedBox(height: 16.h),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.maroon,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: 10.h, left: 2.w),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.maroon,
      ),
    ),
  );
}
