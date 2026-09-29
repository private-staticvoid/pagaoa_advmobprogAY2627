import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../providers/theme_provider.dart';
import '../services/chat_service.dart';
import '../services/unread_store.dart';
import '../services/user_service.dart';
import '../widgets/chat_extras.dart';
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

  // Built once so StreamBuilder doesn't resubscribe on every search keystroke,
  // which made the whole list flash its spinner.
  late final Stream<List<Map<String, dynamic>>> _usersStream =
      _chatService.getUsersStream();
  // Unread counts come from the shared store rather than a StreamBuilder in the
  // tree, so rebuilding the list can't reset them and make the badges blink.
  final UnreadStore _unread = UnreadStore.instance;

  String _currentUid = '';
  String _currentEmail = '';
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
    // Firebase is the source of truth for who is signed in. The saved session
    // is only a fallback, since it can still hold an old uid.
    var uid = _chatService.currentUserId;
    var email = _chatService.currentUserEmail;
    if (uid.isEmpty || email.isEmpty) {
      final userData = await _userService.getUserData();
      if (uid.isEmpty) uid = userData['uid']?.toString() ?? '';
      if (email.isEmpty) email = userData['email']?.toString() ?? '';
    }

    if (!mounted) return;
    setState(() {
      _currentUid = uid;
      _currentEmail = email;
      _loadingUser = false;
    });
    // Also retries if a previous listener died, e.g. the index was still
    // building the first time the chat list was opened.
    _unread.start(uid, force: _unread.failed);
  }

  // Enhancement 1: is this document me? The uid is checked first, but an older
  // profile can be missing that field, so the email is checked as a backup.
  bool _isMe(Map<String, dynamic> user) {
    final uid = user['uid']?.toString() ?? '';
    if (uid.isNotEmpty && _currentUid.isNotEmpty && uid == _currentUid) {
      return true;
    }

    final email = user['email']?.toString().toLowerCase() ?? '';
    return email.isNotEmpty &&
        _currentEmail.isNotEmpty &&
        email == _currentEmail.toLowerCase();
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
                // Says out loud when unread counts aren't working, instead of
                // leaving the badges silently stuck.
                AnimatedBuilder(
                  animation: _unread,
                  builder: (context, _) =>
                      _unread.failed ? _unreadWarning() : const SizedBox.shrink(),
                ),
                Expanded(child: _userList()),
              ],
            ),
    );
  }

  Widget _unreadWarning() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18.sp, color: Colors.orange.shade800),
          SizedBox(width: 10.w),
          Expanded(
            child: CustomText(
              text: 'Unread counts are off. The Firestore index for messages '
                  'is missing — check the Debug Console for the link.',
              fontSize: 11.5.sp,
              maxLines: 3,
              color: Colors.orange.shade900,
            ),
          ),
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
      stream: _usersStream,
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

        // Enhancement 1: drop myself so I never appear in my own chat list.
        // One email can only ever be one account, so if two documents share an
        // email only the first is kept. That hides leftover profiles from
        // accounts that were deleted in the console without their document.
        final seen = <String>{};
        final users = <Map<String, dynamic>>[];
        for (final user in snapshot.data ?? <Map<String, dynamic>>[]) {
          if (_isMe(user) || !_matchesSearch(user)) continue;
          final email = user['email']?.toString().toLowerCase() ?? '';
          final key = email.isNotEmpty ? email : (user['uid']?.toString() ?? '');
          if (key.isEmpty || !seen.add(key)) continue;
          users.add(user);
        }

        if (users.isEmpty) {
          return _message(
            _searchText.isEmpty ? Icons.people_outline : Icons.search_off,
            _searchText.isEmpty
                ? 'No other users yet.'
                : 'No user matches "$_searchText".',
          );
        }

        // Rebuilds only the list when a count changes, not the whole screen.
        return AnimatedBuilder(
          animation: _unread,
          builder: (context, _) => ListView.separated(
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 16.h),
            itemCount: users.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final user = users[index];
              final uid = user['uid']?.toString() ?? '';
              return _userTile(user, _unread.countFor(uid));
            },
          ),
        );
      },
    );
  }

  Widget _userTile(Map<String, dynamic> user, int unreadCount) {
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
          fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: CustomText(
          text: email,
          fontSize: 12.sp,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: unreadCount > 0
            ? UnreadBadge(count: unreadCount)
            : Icon(Icons.chat_bubble_outline, size: 20.sp),
        onTap: () {
          // Clear the badge straight away. Opening the chat marks the messages
          // as seen, but that write has to reach Firestore and come back
          // before the count would drop on its own.
          _unread.clearFor(user['uid']?.toString() ?? '');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                currentUserId: _currentUid,
                tappedUser: user,
              ),
            ),
          );
        },
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
