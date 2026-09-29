import 'dart:async';

import 'package:flutter/foundation.dart';

import 'chat_service.dart';

// One shared place for the unread counts, so the chat button on the home screen
// and the rows in the chat list always show the same numbers.
class UnreadStore extends ChangeNotifier {
  UnreadStore._internal();
  static final UnreadStore instance = UnreadStore._internal();

  StreamSubscription<Map<String, int>>? _subscription;
  Timer? _retryTimer;
  String _uid = '';
  Map<String, int> _counts = const {};
  bool _failed = false;

  Map<String, int> get counts => _counts;

  int get total => _counts.values.fold<int>(0, (sum, count) => sum + count);

  int countFor(String otherUserId) => _counts[otherUserId] ?? 0;

  // True when the Firestore listener died, which almost always means the
  // collection group index hasn't been created yet.
  bool get failed => _failed;

  // Safe to call repeatedly. It only resubscribes when the user changed or the
  // previous listener is gone.
  void start(String uid, {bool force = false}) {
    if (uid.isEmpty) return;
    if (!force && uid == _uid && _subscription != null) return;

    _uid = uid;
    _retryTimer?.cancel();
    _subscription?.cancel();

    _subscription = ChatService().unreadBySender(uid).listen(
      (counts) {
        _failed = false;
        _counts = counts;
        notifyListeners();
      },
      onError: (Object error) {
        // A Firestore query error ends the stream for good, so without this the
        // badge would freeze on its last value until the app restarted.
        debugPrint('[UnreadStore] listener stopped: $error');
        _failed = true;
        _subscription?.cancel();
        _subscription = null;
        notifyListeners();

        // Retry so the badge starts working on its own once the index finishes
        // building, instead of needing a restart.
        _retryTimer?.cancel();
        _retryTimer = Timer(
          const Duration(seconds: 10),
          () => start(uid, force: true),
        );
      },
    );
  }

  // Called when a conversation is opened. Firestore confirms this a moment
  // later; this only stops the badge from lingering in the meantime.
  void clearFor(String otherUserId) {
    if (countFor(otherUserId) == 0) return;

    final updated = Map<String, int>.from(_counts)..remove(otherUserId);
    _counts = updated;
    notifyListeners();
  }

  // Called on logout so the next person to sign in on this device doesn't
  // briefly see the previous user's counts.
  void reset() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _uid = '';
    _counts = const {};
    _failed = false;
    notifyListeners();
  }
}
