// LAB 5 — Account management dialogs (Profile screen, Firebase accounts)
//   showUpdateUsernameDialog  -> UserService.updateUsername
//   showChangePasswordDialog  -> UserService.resetPasswordFromCurrentPassword
//   showDeleteAccountDialog   -> UserService.deleteAccount
//
// Each dialog runs the action itself, shows a spinner while waiting, shows
// the error INSIDE the dialog if it fails, and returns `true` on success.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/user_service.dart';
import '../utils/auth_errors.dart';
import '../utils/validators.dart';
import 'password_field.dart';
import 'password_requirements.dart';

Future<bool> showUpdateUsernameDialog(
  BuildContext context, {
  required String currentUsername,
}) async {
  final controller = TextEditingController(text: currentUsername);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ActionDialog(
      title: 'Update username',
      confirmLabel: 'Save',
      fields: [
        TextFormField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'New username',
            prefixIcon: Icon(Icons.alternate_email, size: 20.sp),
          ),
          validator: Validators.username,
        ),
      ],
      onConfirm: () =>
          UserService().updateUsername(username: controller.text.trim()),
    ),
  );
  return ok ?? false;
}

Future<bool> showChangePasswordDialog(
  BuildContext context, {
  required String email,
}) async {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ActionDialog(
      title: 'Change password',
      confirmLabel: 'Update',
      fields: [
        PasswordField(
          controller: current,
          label: 'Current password',
          textInputAction: TextInputAction.next,
          validator: (v) => Validators.required(v, field: 'Current password'),
        ),
        SizedBox(height: 12.h),
        PasswordField(
          controller: next,
          label: 'New password',
          textInputAction: TextInputAction.next,
          validator: Validators.password,
        ),
        PasswordRequirements(controller: next),
        SizedBox(height: 12.h),
        PasswordField(
          controller: confirm,
          label: 'Confirm new password',
          validator: Validators.confirmPassword(() => next.text),
        ),
      ],
      onConfirm: () => UserService().resetPasswordFromCurrentPassword(
        email: email,
        currentPassword: current.text,
        newPassword: next.text,
      ),
    ),
  );
  return ok ?? false;
}

Future<bool> showDeleteAccountDialog(
  BuildContext context, {
  required String email,
}) async {
  final password = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _ActionDialog(
      title: 'Delete account',
      confirmLabel: 'Delete forever',
      destructive: true,
      fields: [
        Text(
          'This permanently deletes $email and its profile data. '
          'Enter your password to confirm.',
          style: TextStyle(fontSize: 13.sp),
        ),
        SizedBox(height: 14.h),
        PasswordField(
          controller: password,
          label: 'Password',
          validator: (v) => Validators.required(v, field: 'Password'),
        ),
      ],
      onConfirm: () =>
          UserService().deleteAccount(email: email, password: password.text),
    ),
  );
  return ok ?? false;
}

/// Shared dialog shell: form + inline error + loading state.
class _ActionDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final List<Widget> fields;
  final Future<void> Function() onConfirm;
  final bool destructive;

  const _ActionDialog({
    required this.title,
    required this.confirmLabel,
    required this.fields,
    required this.onConfirm,
    this.destructive = false,
  });

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmColor = widget.destructive ? Colors.red.shade700 : null;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...widget.fields,
              if (_error != null) ...[
                SizedBox(height: 12.h),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12.sp),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.confirmLabel,
                  style: TextStyle(
                    color: confirmColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
