import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../providers/theme_provider.dart';
import '../services/chat_service.dart';
import '../widgets/custom_text.dart';

// The actual conversation: bubbles, sending state and the message box.
class ChatDetailScreen extends StatefulWidget {
  final String currentUserId;
  final Map<String, dynamic> tappedUser;

  const ChatDetailScreen({
    super.key,
    required this.currentUserId,
    required this.tappedUser,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  // Message ids that already played their entrance animation, so they don't
  // replay every time the list rebuilds.
  final Set<String> _animated = {};

  bool _canSend = false;

  String get _otherUserId => widget.tappedUser['uid']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final canSend = _messageController.text.trim().isNotEmpty;
      if (canSend != _canSend) setState(() => _canSend = canSend);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear the box right away. Firestore writes to the local cache first, so
    // the bubble shows up instantly with a "sending" clock.
    _messageController.clear();
    _messageFocus.requestFocus();

    try {
      await _chatService.sendMessage(_otherUserId, text);
    } catch (e) {
      if (!mounted) return;
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // Marks the other person's unread messages as seen while I'm reading them.
  void _markIncomingAsSeen(List<QueryDocumentSnapshot> docs) {
    final unseen = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['senderId']?.toString() != widget.currentUserId &&
          data['seen'] != true;
    }).map((doc) => doc.id).toList();

    if (unseen.isEmpty) return;
    // Run after the frame so a Firestore write never happens mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markAsSeen(widget.currentUserId, _otherUserId, unseen);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          _composer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final firstName = widget.tappedUser['firstName']?.toString() ?? '';
    final lastName = widget.tappedUser['lastName']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();

    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 17.r,
            backgroundColor: Colors.white,
            child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.maroon,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  text: fullName.isNotEmpty ? fullName : 'Unknown',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                CustomText(
                  text: widget.tappedUser['email']?.toString() ?? '',
                  fontSize: 11.sp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    if (_otherUserId.isEmpty) {
      return Center(
        child: CustomText(
          text: 'This user has no Firebase ID, so no chat can be opened.',
          fontSize: 14.sp,
          textAlign: TextAlign.center,
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(widget.currentUserId, _otherUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: CustomText(
              text: 'Error loading messages.',
              fontSize: 14.sp,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: CustomText(
              text: 'No messages yet. Say hi!',
              fontSize: 14.sp,
              color: Colors.grey,
            ),
          );
        }

        _markIncomingAsSeen(docs);

        // Newest first from Firestore + reverse ListView = newest at bottom,
        // and it opens already scrolled to the latest message.
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          itemCount: docs.length,
          itemBuilder: (context, index) => _bubble(docs[index]),
        );
      },
    );
  }

  Widget _bubble(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final text = data['message']?.toString() ?? '';
    final isMine = data['senderId']?.toString() == widget.currentUserId;

    // hasPendingWrites is true while the write is still only in the local
    // cache, which is exactly the "sending..." state.
    final isSending = doc.metadata.hasPendingWrites;
    final isSeen = data['seen'] == true;
    final isNew = _animated.add(doc.id);

    final theme = Theme.of(context);
    final bubbleColor = isMine
        ? theme.colorScheme.primary
        : (theme.brightness == Brightness.dark
              ? const Color(0xFF3A2A2E)
              : AppColors.maroonLight);
    final textColor = isMine ? Colors.white : theme.colorScheme.onSurface;

    return _SlideFadeIn(
      animate: isNew,
      fromRight: isMine,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            // Square off the corner nearest the sender so it reads like a tail.
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(isMine ? 16.r : 4.r),
              bottomRight: Radius.circular(isMine ? 4.r : 16.r),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomText(
                text: text,
                fontSize: 14.sp,
                color: textColor,
                textAlign: TextAlign.left,
              ),
              SizedBox(height: 3.h),
              _statusLine(data, isMine, isSending, isSeen, textColor),
            ],
          ),
        ),
      ),
    );
  }

  // Time under every message, plus the sending/delivered/seen mark on mine.
  Widget _statusLine(
    Map<String, dynamic> data,
    bool isMine,
    bool isSending,
    bool isSeen,
    Color textColor,
  ) {
    final faded = textColor.withValues(alpha: 0.7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomText(
          text: isSending ? 'sending...' : _formatTime(data['timestamp']),
          fontSize: 10.sp,
          color: faded,
        ),
        if (isMine && !isSending) ...[
          SizedBox(width: 4.w),
          Icon(
            isSeen ? Icons.done_all : Icons.done,
            size: 13.sp,
            color: isSeen ? AppColors.gold : faded,
          ),
        ],
        if (isMine && isSending) ...[
          SizedBox(width: 4.w),
          Icon(Icons.schedule, size: 13.sp, color: faded),
        ],
      ],
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp is! Timestamp) return '';
    final time = timestamp.toDate().toLocal();
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocus,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            // Send button greys out until something is typed.
            AnimatedScale(
              scale: _canSend ? 1 : 0.9,
              duration: const Duration(milliseconds: 150),
              child: CircleAvatar(
                radius: 23.r,
                backgroundColor: _canSend
                    ? AppColors.gold
                    : Colors.grey.shade400,
                child: IconButton(
                  icon: Icon(Icons.send, size: 20.sp, color: Colors.black87),
                  onPressed: _canSend ? _send : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fades and slides a new bubble in. Old bubbles are built with animate:false
// so scrolling doesn't make them flash.
class _SlideFadeIn extends StatelessWidget {
  final Widget child;
  final bool animate;
  final bool fromRight;

  const _SlideFadeIn({
    required this.child,
    required this.animate,
    required this.fromRight,
  });

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset((fromRight ? 28 : -28) * (1 - value), 0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
