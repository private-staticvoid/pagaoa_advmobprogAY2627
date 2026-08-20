// ENHANCEMENT 2 — Sign-in screen
// Custom UI: card-based form on the maroon/gold theme
// Wires to UserService.loginUser(username, password), which already
// persists the session on success
// Link to the new /signup screen, plus a "Demo accounts" hint box,
// since DummyJSON's login only accepts its own seeded demo users.
// Full-screen BrandLoadingView (from splash_screen.dart) overlays the
// form while logging in, instead of just a spinner in the button.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import 'splash_screen.dart';
import '../widgets/password_field.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userService = UserService();

  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // UserService.loginUser already calls saveUserData() internally on
      // success, so by the time this returns the session is persisted.
      final response = await _userService.loginUser(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      // Note: not resetting _isLoading here on purpose — this screen is
      // about to be replaced, so the overlay just stays up until then
      // instead of flashing back to the form for a frame.
      Navigator.pushReplacementNamed(context, '/home', arguments: response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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
                    SizedBox(height: 24.h),
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
                    SizedBox(height: 32.h),

                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline, size: 20.sp),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your username'
                          : null,
                    ),
                    SizedBox(height: 16.h),

                    // Enhancement 2: password field with visibility toggle.
                    PasswordField(
                      controller: _passwordController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    SizedBox(height: 28.h),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: Text(
                        'Log In',
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
                    SizedBox(height: 28.h),

                    // Helper box: DummyJSON only authenticates its seeded
                  ],
                ),
              ),
            ),
          ),

          // Full-screen brand loading view, shown over the form while
          // _login() is in flight.
          if (_isLoading)
            const Positioned.fill(child: BrandLoadingView(subtitle: null)),
        ],
      ),
    );
  }
}
