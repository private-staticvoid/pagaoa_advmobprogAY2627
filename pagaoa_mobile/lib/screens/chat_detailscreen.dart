import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../providers/theme_provider.dart';
import '../services/chat_service.dart';
import '../widgets/chat_extras.dart';
import '../widgets/custom_text.dart';
import 'chat_profile_screen.dart';

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

  // Built once in initState. Creating it inside build() made StreamBuilder
  // resubscribe on every setState, which flashed the loading spinner.
  late final Stream<QuerySnapshot> _messagesStream;
  late final Stream<Timestamp?> _typingStream;

  // Typing is only reported every few seconds, not on every keystroke, so it
  // doesn't turn into one Firestore write per letter.
  Timer? _typingStopTimer;
  DateTime? _lastTypingPing;

  // Message ids that already played their entrance animation, so they don't
  // replay every time the list rebuilds.
  final Set<String> _animated = {};

  bool _canSend = false;

  // Set when swiping a bubble to reply, cleared after sending or cancelling.
  String? _replyToId;
  String? _replyToMessage;
  String? _replyToSenderId;

  String get _otherUserId => widget.tappedUser['uid']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.getMessages(
      widget.currentUserId,
      _otherUserId,
    );
    _typingStream = _chatService.typingStream(
      widget.currentUserId,
      _otherUserId,
    );
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final canSend = text.trim().isNotEmpty;
    if (canSend != _canSend) setState(() => _canSend = canSend);

    if (text.isEmpty) {
      _stopTyping();
    } else {
      _pingTyping();
    }
  }

  // Tell the other side I'm typing, at most once every 3 seconds, and stop
  // automatically after 4 seconds of no keystrokes.
  void _pingTyping() {
    final now = DateTime.now();
    if (_lastTypingPing == null ||
        now.difference(_lastTypingPing!).inSeconds >= 3) {
      _lastTypingPing = now;
      _chatService.setTyping(_otherUserId, true);
    }

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 4), _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    if (_lastTypingPing == null) return;
    _lastTypingPing = null;
    _chatService.setTyping(_otherUserId, false);
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatProfileScreen(user: widget.tappedUser),
      ),
    );
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    _stopTyping();
    _messageController.dispose();
    _messageFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startReply(String id, String message, String senderId) {
    setState(() {
      _replyToId = id;
      _replyToMessage = message;
      _replyToSenderId = senderId;
    });
    _messageFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToMessage = null;
      _replyToSenderId = null;
    });
  }

  Future<void> _send({String? sticker}) async {
    final text = sticker ?? _messageController.text.trim();
    if (text.isEmpty) return;

    // Capture the reply before clearing, so the send below still has it.
    final replyToId = _replyToId;
    final replyToMessage = _replyToMessage;
    final replyToSenderId = _replyToSenderId;

    // Clear the box right away. Firestore writes to the local cache first, so
    // the bubble shows up instantly with a "sending" clock.
    if (sticker == null) _messageController.clear();
    _cancelReply();
    _stopTyping();
    _messageFocus.requestFocus();

    try {
      await _chatService.sendMessage(
        _otherUserId,
        text,
        type: sticker == null ? 'text' : 'sticker',
        replyToId: replyToId,
        replyToMessage: replyToMessage,
        replyToSenderId: replyToSenderId,
      );
    } catch (e) {
      if (!mounted) return;
      if (sticker == null) _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _pickSticker() async {
    final sticker = await showStickerPicker(context);
    if (sticker != null) await _send(sticker: sticker);
  }

  Future<void> _react(String messageId, Map<String, dynamic> data) async {
    final emoji = await showReactionPicker(context);
    if (emoji == null) return;

    final reactions = (data['reactions'] as Map?) ?? {};
    final mine = reactions[widget.currentUserId]?.toString();

    await _chatService.toggleReaction(
      widget.currentUserId,
      _otherUserId,
      messageId,
      emoji,
      mine,
    );
  }

  // Marks the other person's unread messages as seen while I'm reading them.
  void _markIncomingAsSeen(List<QueryDocumentSnapshot> docs) {
    final unseen = docs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['senderId']?.toString() != widget.currentUserId &&
              data['seen'] != true;
        })
        .map((doc) => doc.id)
        .toList();

    if (unseen.isEmpty) return;
    // Run after the frame so a Firestore write never happens mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markAsSeen(widget.currentUserId, _otherUserId, unseen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.tappedUser['firstName']?.toString().trim() ?? '';

    return Scaffold(
      appBar: _appBar(),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          TypingIndicator(
            typingStream: _typingStream,
            name: firstName.isNotEmpty ? firstName : 'They',
          ),
          if (_replyToId != null) _replyPreview(),
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
      actions: [
        IconButton(
          icon: Icon(Icons.info_outline, size: 22.sp),
          tooltip: 'View profile',
          onPressed: _openProfile,
        ),
      ],
      // Tapping the name opens their profile, same as most chat apps.
      title: InkWell(
        onTap: _openProfile,
        child: Row(
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
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: CustomText(text: 'Error loading messages.', fontSize: 14.sp),
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
          itemBuilder: (context, index) => _swipeToReply(docs[index]),
        );
      },
    );
  }

  // Dismissible gives the drag and the snap-back for free. Returning false
  // from confirmDismiss means the bubble slides back instead of disappearing.
  Widget _swipeToReply(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.28},
      confirmDismiss: (_) async {
        _startReply(
          doc.id,
          data['message']?.toString() ?? '',
          data['senderId']?.toString() ?? '',
        );
        return false;
      },
      background: Padding(
        padding: EdgeInsets.only(left: 14.w),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Icon(Icons.reply, size: 20.sp, color: AppColors.maroon),
        ),
      ),
      child: _bubble(doc, data),
    );
  }

  Widget _bubble(QueryDocumentSnapshot doc, Map<String, dynamic> data) {
    final text = data['message']?.toString() ?? '';
    final isMine = data['senderId']?.toString() == widget.currentUserId;
    final isSticker = data['type']?.toString() == 'sticker';

    // hasPendingWrites is true while a write is still only in the local cache.
    // It also turns true on the other person's messages while my "seen" update
    // syncs, so this only counts as sending on my own messages.
    final isSending = isMine && doc.metadata.hasPendingWrites;
    final isSeen = data['seen'] == true;
    final isNew = _animated.add(doc.id);

    final theme = Theme.of(context);
    final bubbleColor = isMine
        ? theme.colorScheme.primary
        : (theme.brightness == Brightness.dark
              ? const Color(0xFF3A2A2E)
              : AppColors.maroonLight);
    final textColor = isMine ? Colors.white : theme.colorScheme.onSurface;

    // A sticker is shown on its own, no bubble behind it.
    final Widget content = isSticker
        ? Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 6.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, style: TextStyle(fontSize: 52.sp)),
                _statusLine(
                  data,
                  isMine,
                  isSending,
                  isSeen,
                  theme.colorScheme.onSurface,
                ),
              ],
            ),
          )
        : Container(
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
                if (data['replyToId'] != null)
                  _quotedReply(data, isMine, textColor),
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
          );

    return _SlideFadeIn(
      animate: isNew,
      fromRight: isMine,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _react(doc.id, data),
            child: Align(
              alignment: isMine
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: content,
            ),
          ),
          _reactionChips(data),
        ],
      ),
    );
  }

  // The quoted message shown inside a bubble that is a reply.
  Widget _quotedReply(
    Map<String, dynamic> data,
    bool isMine,
    Color textColor,
  ) {
    final quoted = data['replyToMessage']?.toString() ?? '';
    final quotedIsMine =
        data['replyToSenderId']?.toString() == widget.currentUserId;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border(
          left: BorderSide(color: textColor.withValues(alpha: 0.5), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomText(
            text: quotedIsMine ? 'You' : 'Them',
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: textColor.withValues(alpha: 0.8),
          ),
          CustomText(
            text: quoted,
            fontSize: 12.sp,
            color: textColor.withValues(alpha: 0.8),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Reaction emoji shown under the bubble, grouped so 2 hearts show as "❤️ 2".
  Widget _reactionChips(Map<String, dynamic> data) {
    final reactions = (data['reactions'] as Map?) ?? {};
    if (reactions.isEmpty) return const SizedBox.shrink();

    final counts = <String, int>{};
    for (final value in reactions.values) {
      final emoji = value.toString();
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return Container(
      margin: EdgeInsets.only(top: 2.h, bottom: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        counts.entries
            .map((e) => e.value > 1 ? '${e.key} ${e.value}' : e.key)
            .join('  '),
        style: TextStyle(fontSize: 12.sp),
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

  // Bar above the composer showing what I'm replying to.
  Widget _replyPreview() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 8.w, 8.h),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34.h,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  text: _replyToSenderId == widget.currentUserId
                      ? 'Replying to yourself'
                      : 'Replying to them',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
                CustomText(
                  text: _replyToMessage ?? '',
                  fontSize: 12.sp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18.sp),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 6.h, 12.w, 10.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.emoji_emotions_outlined, size: 24.sp),
              tooltip: 'Stickers',
              onPressed: _pickSticker,
            ),
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
