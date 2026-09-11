// Sign in screen (Lab 4, updated for Lab 5)
// Lab 5: a toggle at the top chooses the backend:
//   DummyJSON -> username + password -> UserService.loginUser()
//   Firebase  -> email + password    -> UserService.loginWithFirebase()
// Both save the session with a LoginType, then go to /home.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants.dart';
import '../models/login_type.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../utils/auth_errors.dart';
import '../utils/validators.dart';
import '../widgets/password_field.dart';
import 'splash_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(); // username OR email
  final _passwordController = TextEditingController();
  final _userService = UserService();

  LoginType _loginType = LoginType.firebase;
  bool _isLoading = false;

  bool get _isFirebase => _loginType == LoginType.firebase;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final id = _identifierController.text.trim();
      final password = _passwordController.text;

      if (_isFirebase) {
        await _userService.loginWithFirebase(email: id, password: password);
      } else {
        await _userService.loginUser(id, password);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: ${friendlyAuthError(e)}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _switchType(LoginType type) {
    setState(() {
      _loginType = type;
      _identifierController.clear();
      _passwordController.clear();
    });
    _formKey.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 16.h),
                    Icon(
                      Icons.storefront_rounded,
                      color: AppColors.maroon,
                      size: 56.sp,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.maroon,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Sign in to continue to NUBD Exchange',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // Lab 5: choose the backend.
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
                      selected: {_loginType},
                      onSelectionChanged: (s) => _switchType(s.first),
                    ),
                    SizedBox(height: 20.h),

                    TextFormField(
                      controller: _identifierController,
                      textInputAction: TextInputAction.next,
                      keyboardType: _isFirebase
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: _isFirebase ? 'Email' : 'Username',
                        prefixIcon: Icon(
                          _isFirebase
                              ? Icons.email_outlined
                              : Icons.person_outline,
                          size: 20.sp,
                        ),
                      ),
                      validator: _isFirebase
                          ? Validators.email
                          : (v) => Validators.required(v, field: 'Username'),
                    ),
                    SizedBox(height: 16.h),

                    // Login only checks that a password was typed; the
                    // strength rules are enforced on sign up.
                    PasswordField(
                      controller: _passwordController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      validator: (v) =>
                          Validators.required(v, field: 'Password'),
                    ),
                    SizedBox(height: 28.h),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: Text(
                        'Log In with ${_loginType.label}',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.maroon,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    if (!_isFirebase) _buildDemoAccounts(),
                  ],
                ),
              ),
            ),
          ),

          if (_isLoading)
            const Positioned.fill(child: BrandLoadingView(subtitle: null)),
        ],
      ),
    );
  }

  /// DummyJSON only accepts its own seeded users — tap one to fill the form.
  Widget _buildDemoAccounts() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.maroonLight,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DummyJSON demo accounts (tap to fill)',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.maroon,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: demoAccounts.map((acc) {
              return ActionChip(
                label: Text(acc['username']!),
                onPressed: () {
                  _identifierController.text = acc['username']!;
                  _passwordController.text = acc['password']!;
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
