import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/login_type.dart';
import '../models/user.dart';
import '../providers/theme_provider.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

// Settings page: theme (Lab 1) + Account / Logout (Lab 5, Enhancement 3).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _userService = UserService();
  late final Future<User> _userFuture = _userService.getUser();
  bool themeChanged = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Log out',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Clears Firebase session + SharedPreferences token + cached cart.
    await _userService.logout();
    if (!mounted) return;
    // Remove EVERY screen from the stack so "back" can't return to home.
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: 'Settings',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 24.sp),
          onPressed: () => Navigator.pop(context, themeChanged),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 30.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 35.r,
                  child: Icon(Icons.palette, size: 35.sp),
                ),
                SizedBox(height: 12.h),
                CustomText(
                  text: 'Appearance',
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 4.h),
                CustomText(text: 'Customize your app theme', fontSize: 13.sp),
              ],
            ),
          ),
          SizedBox(height: 25.h),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: SwitchListTile(
              secondary: Text(
                themeModel.isDark ? "🌙" : "🌞",
                style: TextStyle(fontSize: 26.sp),
              ),
              title: CustomText(
                text: themeModel.isDark ? "Night Mode" : "Day Mode",
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
              subtitle: CustomText(
                text: themeModel.isDark
                    ? "Dark theme enabled"
                    : "Light theme enabled",
                fontSize: 12.sp,
              ),
              value: themeModel.isDark,
              onChanged: (_) {
                themeModel.toggleTheme();
                setState(() => themeChanged = true);
              },
            ),
          ),
          SizedBox(height: 25.h),

          // ---------------- Lab 5: Account ----------------
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
            child: CustomText(
              text: 'Account',
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Column(
              children: [
                FutureBuilder<User>(
                  future: _userFuture,
                  builder: (context, snap) {
                    final user = snap.data;
                    return ListTile(
                      leading: Icon(
                        user?.isFirebase == true
                            ? Icons.local_fire_department_outlined
                            : Icons.cloud_outlined,
                        color: AppColors.gold,
                      ),
                      title: Text(
                        user == null
                            ? 'Loading...'
                            : (user.email.isNotEmpty
                                  ? user.email
                                  : user.username),
                      ),
                      subtitle: Text(
                        user == null
                            ? ''
                            : 'Signed in with ${user.loginType.label}',
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade400),
                  title: Text(
                    'Log out',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
