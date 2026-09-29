import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/message_model.dart';

// Everything the chat screens need from Firestore. The screens never touch
// FirebaseFirestore directly, same rule I followed with UserService.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Both users must land on the same room, so the two uids are sorted first.
  // "abc_xyz" is the same room whoever opens it.
  String chatRoomIdFor(String userId, String otherUserId) {
    final ids = [userId, otherUserId]..sort();
    return ids.join('_');
  }

  // Who is signed in right now. This comes straight from Firebase instead of
  // SharedPreferences so it can never be a stale uid from an old session.
  String get currentUserId => _firebaseAuth.currentUser?.uid ?? '';

  String get currentUserEmail => _firebaseAuth.currentUser?.email ?? '';

  CollectionReference<Map<String, dynamic>> _messagesRef(
    String userId,
    String otherUserId,
  ) {
    return _firestore
        .collection(chatRoomsCollection)
        .doc(chatRoomIdFor(userId, otherUserId))
        .collection('messages');
  }

  // Every account in the users collection, used by the chat list.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection(usersCollection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        // The document ID is always the uid, so fill the field in when an
        // older document is missing it. Without this the chat list cannot
        // tell which document is mine.
        if ((user['uid']?.toString() ?? '').isEmpty) {
          user['uid'] = doc.id;
        }
        return user;
      }).toList();
    });
  }

  Future<void> sendMessage(
    String receiverId,
    String message, {
    String type = 'text',
    String? replyToId,
    String? replyToMessage,
    String? replyToSenderId,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) throw Exception('You are not signed in.');

    final newMessage = MessageModel(
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? '',
      receiverId: receiverId,
      message: message,
      timestamp: Timestamp.now(),
      type: type,
      replyToId: replyToId,
      replyToMessage: replyToMessage,
      replyToSenderId: replyToSenderId,
    );

    await _messagesRef(currentUser.uid, receiverId).add(newMessage.toMap());
  }

  // includeMetadataChanges lets the UI see hasPendingWrites, which is how the
  // bubble knows to show "sending..." before the server confirms it.
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    return _messagesRef(userId, otherUserId)
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  // Tapping the same emoji again removes it, so one person has one reaction.
  Future<void> toggleReaction(
    String userId,
    String otherUserId,
    String messageId,
    String emoji,
    String? currentEmoji,
  ) async {
    final field = 'reactions.$userId';
    try {
      await _messagesRef(userId, otherUserId).doc(messageId).update({
        field: currentEmoji == emoji ? FieldValue.delete() : emoji,
      });
    } catch (e) {
      debugPrint('[ChatService] reaction failed: $e');
    }
  }

  // Flips seen to true on messages I just read, so the sender gets blue ticks.
  Future<void> markAsSeen(
    String userId,
    String otherUserId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;

    final messages = _messagesRef(userId, otherUserId);
    final batch = _firestore.batch();
    for (final id in messageIds) {
      batch.update(messages.doc(id), {'seen': true});
    }

    try {
      await batch.commit();
    } catch (e) {
      // Not worth interrupting the chat over, the ticks just stay grey.
      debugPrint('[ChatService] markAsSeen skipped: $e');
    }
  }

  // Unread counts for the badges, as senderId -> how many they sent me.
  // collectionGroup searches the messages subcollection of every chat room at
  // once, so one stream covers all conversations. Needs the composite index
  // Firestore asks for the first time this runs.
  Stream<Map<String, int>> unreadBySender(String myUid) {
    return _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: myUid)
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final senderId = doc.data()['senderId']?.toString() ?? '';
        if (senderId.isEmpty) continue;
        counts[senderId] = (counts[senderId] ?? 0) + 1;
      }
      return counts;
    });
  }

  // Live profile of one user, so the profile screen updates if they rename.
  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _firestore.collection(usersCollection).doc(uid).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null) return null;
      if ((data['uid']?.toString() ?? '').isEmpty) data['uid'] = doc.id;
      return data;
    });
  }

  // TYPING INDICATOR
  // The chat room document holds a `typing` map of uid -> last keystroke time.
  // A timestamp is used instead of a plain true/false so a stale "typing" can
  // expire on its own if the other app is closed mid-sentence.
  Future<void> setTyping(String otherUserId, bool typing) async {
    final uid = currentUserId;
    if (uid.isEmpty || otherUserId.isEmpty) return;

    try {
      await _firestore
          .collection(chatRoomsCollection)
          .doc(chatRoomIdFor(uid, otherUserId))
          .set({
            'typing': {uid: typing ? Timestamp.now() : null},
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatService] setTyping skipped: $e');
    }
  }

  // The other person's last keystroke time, or null if they aren't typing.
  // The widget decides how fresh that has to be to count.
  Stream<Timestamp?> typingStream(String userId, String otherUserId) {
    return _firestore
        .collection(chatRoomsCollection)
        .doc(chatRoomIdFor(userId, otherUserId))
        .snapshots()
        .map((doc) {
      final typing = doc.data()?['typing'] as Map<String, dynamic>?;
      final value = typing?[otherUserId];
      return value is Timestamp ? value : null;
    });
  }

  Future<String?> getUidByEmail(String email) async {
    final result = await _firestore
        .collection(usersCollection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (result.docs.isEmpty) return null;
    return (result.docs.first.data()['uid'] ?? '').toString();
  }
}
