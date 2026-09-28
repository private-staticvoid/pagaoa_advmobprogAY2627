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

  // Every account in the users collection, used by the chat list.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore
        .collection(usersCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> sendMessage(String receiverId, String message) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) throw Exception('You are not signed in.');

    final newMessage = MessageModel(
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? '',
      receiverId: receiverId,
      message: message,
      timestamp: Timestamp.now(),
    );

    await _firestore
        .collection(chatRoomsCollection)
        .doc(chatRoomIdFor(currentUser.uid, receiverId))
        .collection('messages')
        .add(newMessage.toMap());
  }

  // includeMetadataChanges lets the UI see hasPendingWrites, which is how the
  // bubble knows to show "sending..." before the server confirms it.
  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    return _firestore
        .collection(chatRoomsCollection)
        .doc(chatRoomIdFor(userId, otherUserId))
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  // Flips seen to true on messages I just read, so the sender gets blue ticks.
  Future<void> markAsSeen(
    String userId,
    String otherUserId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return;

    final messages = _firestore
        .collection(chatRoomsCollection)
        .doc(chatRoomIdFor(userId, otherUserId))
        .collection('messages');

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
