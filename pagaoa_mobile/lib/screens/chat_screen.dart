import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../providers/theme_provider.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';
import 'chat_detailscreen.dart';

// Chat list. Shows every registered user except me, with a search bar on top.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  String _currentUid = '';
  String _searchText = '';
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(
      () => setState(() => _searchText = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final userData = await _userService.getUserData();
    if (!mounted) return;
    setState(() {
      _currentUid = userData['uid']?.toString() ?? '';
      _loadingUser = false;
    });
  }

  // Enhancement 2: match against name, username or email.
  bool _matchesSearch(Map<String, dynamic> user) {
    if (_searchText.isEmpty) return true;
    final haystack = [
      user['firstName'],
      user['lastName'],
      user['username'],
      user['email'],
    ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
    return haystack.contains(_searchText.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: 'Chat',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          // DummyJSON accounts have no Firebase uid, so they have no chat.
          : _currentUid.isEmpty
          ? _signedOutNotice()
          : Column(
              children: [
                _searchBar(),
                Expanded(child: _userList()),
              ],
            ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          prefixIcon: Icon(Icons.search, size: 20.sp),
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 20.sp),
                  onPressed: () => _searchController.clear(),
                ),
        ),
      ),
    );
  }

  Widget _userList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _message(
            Icons.error_outline,
            'Could not load users.\nCheck the Firestore rules.',
          );
        }

        // Enhancement 1: drop myself so I can't appear in my own chat list.
        final users = (snapshot.data ?? [])
            .where((u) => u['uid']?.toString() != _currentUid)
            .where(_matchesSearch)
            .toList();

        if (users.isEmpty) {
          return _message(
            _searchText.isEmpty ? Icons.people_outline : Icons.search_off,
            _searchText.isEmpty
                ? 'No other users yet.'
                : 'No user matches "$_searchText".',
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 16.h),
          itemCount: users.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (context, index) => _userTile(users[index]),
        );
      },
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final firstName = user['firstName']?.toString() ?? '';
    final lastName = user['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = user['email']?.toString() ?? 'No email';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        leading: CircleAvatar(
          radius: 24.r,
          backgroundColor: AppColors.maroonLight,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.maroon,
            ),
          ),
        ),
        title: CustomText(
          text: fullName.isNotEmpty
              ? fullName
              : (user['username']?.toString() ?? 'Unknown'),
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: CustomText(
          text: email,
          fontSize: 12.sp,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chat_bubble_outline, size: 20.sp),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              currentUserId: _currentUid,
              tappedUser: user,
            ),
          ),
        ),
      ),
    );
  }

  Widget _signedOutNotice() => _message(
    Icons.lock_outline,
    'Chat is only available for Firebase accounts.\n'
    'Log in with Firebase to start chatting.',
  );

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44.sp, color: Colors.grey),
            SizedBox(height: 12.h),
            CustomText(
              text: text,
              fontSize: 14.sp,
              textAlign: TextAlign.center,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }
}
