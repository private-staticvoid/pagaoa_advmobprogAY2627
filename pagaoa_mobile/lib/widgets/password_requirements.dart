// LAB 5 — Live password checklist
// Listens to a password controller and ticks each rule as the user types.
// The same rules are enforced on submit by Validators.password().

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/validators.dart';

class PasswordRequirements extends StatelessWidget {
  final TextEditingController controller;

  const PasswordRequirements({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final results = Validators.checkPassword(value.text);
        return Padding(
          padding: EdgeInsets.only(left: 4.w, top: 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: Validators.passwordRules.entries.map((rule) {
              final ok = results[rule.key] ?? false;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  children: [
                    Icon(
                      ok ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 15.sp,
                      color: ok ? Colors.green.shade600 : Colors.grey,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      rule.value,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: ok ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
