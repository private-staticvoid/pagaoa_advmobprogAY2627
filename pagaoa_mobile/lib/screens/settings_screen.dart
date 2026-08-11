import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../widgets/custom_text.dart';

// Theme settings page.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool themeChanged = false;

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        // ENHANCEMENT 3 (Settings alignment): CustomText + .sp instead of
        // plain Text, so this matches the typography used on Home/Product/
        // Detail screens rather than looking like a separate app.
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
        // ENHANCEMENT 3 (Settings alignment): swapped hard-coded pixel
        // values (EdgeInsets.all(20), radius 35, fontSize 22, etc.) for
        // ScreenUtil's .w/.h/.r/.sp so spacing/scaling matches the rest
        // of the app on different screen sizes.
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
        ],
      ),
    );
  }
}
