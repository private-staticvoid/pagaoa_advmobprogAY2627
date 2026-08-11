import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../widgets/custom_text.dart';

// "Coming Soon" placeholder used by the Chat and Profile tabs, which
// aren't built yet, instead of leaving those tabs blank or broken.
class ComingSoonScreen extends StatelessWidget {
  final String label;
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.label,
    this.icon = Icons.hourglass_empty,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64.sp, color: Colors.grey),
          SizedBox(height: 16.h),
          CustomText(
            text: '$label — Coming Soon',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
          SizedBox(height: 8.h),
          CustomText(
            text: 'This feature is still under development.',
            fontSize: 13.sp,
          ),
        ],
      ),
    );
  }
}
