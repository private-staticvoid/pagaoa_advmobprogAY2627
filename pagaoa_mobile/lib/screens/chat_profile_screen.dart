import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../providers/theme_provider.dart';
import '../services/chat_service.dart';
import '../widgets/custom_text.dart';

// Profile of the person I'm chatting with. Reads their users document live, so
// if they rename themselves it updates here without reopening the screen.
class ChatProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ChatProfileScreen({super.key, required this.user});

  @override
  State<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends State<ChatProfileScreen> {
  final ChatService _chatService = ChatService();
  late final Stream<Map<String, dynamic>?> _profileStream;

  @override
  void initState() {
    super.initState();
    final uid = widget.user['uid']?.toString() ?? '';
    _profileStream = _chatService.userStream(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: 'Profile',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _profileStream,
        builder: (context, snapshot) {
          // Fall back to the data the chat list already had, so the screen is
          // never blank while the document loads.
          final user = snapshot.data ?? widget.user;

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _header(user),
              SizedBox(height: 16.h),
              _details(user),
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Back to chat'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Map<String, dynamic> user) {
    final firstName = user['firstName']?.toString() ?? '';
    final lastName = user['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final username = user['username']?.toString() ?? '';

    final initials = [firstName, lastName]
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();

    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
        child: Column(
          children: [
            CircleAvatar(
              radius: 46.r,
              backgroundColor: AppColors.maroonLight,
              child: Text(
                initials.isNotEmpty ? initials : '?',
                style: TextStyle(
                  fontSize: 30.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.maroon,
                ),
              ),
            ),
            SizedBox(height: 14.h),
            CustomText(
              text: fullName.isNotEmpty ? fullName : 'Unknown',
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              textAlign: TextAlign.center,
            ),
            if (username.isNotEmpty) ...[
              SizedBox(height: 2.h),
              CustomText(
                text: '@$username',
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _details(Map<String, dynamic> user) {
    final age = user['age'];
    final rows = <Widget>[
      _infoRow(
        Icons.email_outlined,
        'Email',
        user['email']?.toString() ?? '',
      ),
      _infoRow(
        Icons.cake_outlined,
        'Age',
        (age == null || age.toString() == '0') ? '' : age.toString(),
      ),
      _infoRow(Icons.wc_outlined, 'Gender', user['gender']?.toString() ?? ''),
      _infoRow(
        Icons.phone_outlined,
        'Contact No.',
        user['phone']?.toString() ?? '',
      ),
      _infoRow(Icons.fingerprint, 'User ID', user['uid']?.toString() ?? ''),
      _infoRow(
        Icons.event_outlined,
        'Member since',
        _formatDate(user['createdAt']),
      ),
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate().toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.gold),
          SizedBox(width: 12.w),
          CustomText(
            text: label,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
          const Spacer(),
          Flexible(
            child: CustomText(
              text: value.isEmpty ? '—' : value,
              fontSize: 13.sp,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
