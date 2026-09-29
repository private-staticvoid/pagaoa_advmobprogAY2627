import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Emoji used for reactions and for the sticker sheet. Keeping them here means
// the chat screen stays about layout instead of long emoji lists.
const List<String> kReactionEmojis = ['❤️', '😂', '😮', '😢', '👍', '👎'];

const List<String> kStickers = [
  '😀', '😂', '🥹', '😍', '🤩', '😎',
  '🥳', '😴', '🤔', '🙃', '😭', '😤',
  '👍', '👏', '🙏', '💪', '🤝', '✌️',
  '❤️', '🔥', '⭐', '🎉', '💯', '🚀',
  '🐶', '🐱', '🦄', '🍕', '☕', '🌙',
];

// The little emoji row that pops up when a bubble is long pressed.
Future<String?> showReactionPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: kReactionEmojis.map((emoji) {
            return InkWell(
              borderRadius: BorderRadius.circular(30.r),
              onTap: () => Navigator.pop(sheetContext, emoji),
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Text(emoji, style: TextStyle(fontSize: 28.sp)),
              ),
            );
          }).toList(),
        ),
      ),
    ),
  );
}

// Grid of stickers. A sticker is sent as a message with type 'sticker'.
Future<String?> showStickerPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stickers',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.h),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: kStickers.map((sticker) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12.r),
                  onTap: () => Navigator.pop(sheetContext, sticker),
                  child: Center(
                    child: Text(sticker, style: TextStyle(fontSize: 30.sp)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

// Red count badge used on the chat button and on each chat list row.
class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      constraints: BoxConstraints(minWidth: 20.w),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// The "... is typing" bubble. It listens for the other person's last keystroke
// time and also re-checks on a timer, so the bubble disappears on its own even
// if their app closed without clearing the flag.
class TypingIndicator extends StatefulWidget {
  final Stream<Timestamp?> typingStream;
  final String name;

  const TypingIndicator({
    super.key,
    required this.typingStream,
    required this.name,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  // A keystroke counts as "still typing" for this long.
  static const _freshFor = Duration(seconds: 6);

  StreamSubscription<Timestamp?>? _subscription;
  Timer? _ticker;
  Timestamp? _lastKeystroke;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _subscription = widget.typingStream.listen((timestamp) {
      if (!mounted) return;
      setState(() => _lastKeystroke = timestamp);
    });

    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    _dots.dispose();
    super.dispose();
  }

  bool get _isTyping {
    final last = _lastKeystroke;
    if (last == null) return false;
    return DateTime.now().difference(last.toDate()) < _freshFor;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTyping) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final bubbleColor = theme.brightness == Brightness.dark
        ? const Color(0xFF3A2A2E)
        : const Color(0xFFF6E4E7);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 12.w, bottom: 6.h),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(4.r),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.name} is typing',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(width: 6.w),
              AnimatedBuilder(
                animation: _dots,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      // Each dot peaks a third of a cycle after the one before.
                      final phase = (_dots.value * 3 - index).clamp(0.0, 1.0);
                      final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                        child: Opacity(
                          opacity: (0.3 + 0.7 * wave).clamp(0.3, 1.0),
                          child: Container(
                            width: 5.w,
                            height: 5.w,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
