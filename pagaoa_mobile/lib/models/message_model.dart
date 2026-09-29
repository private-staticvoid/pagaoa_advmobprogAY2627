import 'package:cloud_firestore/cloud_firestore.dart';

// One chat message inside chat_rooms/{chatRoomId}/messages.
class MessageModel {
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final bool seen; // set to true once the receiver opens the chat

  // 'text' or 'sticker'. A sticker is just a big emoji with no bubble.
  final String type;

  // Filled in when this message is a reply to another one.
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToSenderId;

  // uid -> emoji. One reaction per person, same as Messenger.
  final Map<String, String> reactions;

  MessageModel({
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.seen = false,
    this.type = 'text',
    this.replyToId,
    this.replyToMessage,
    this.replyToSenderId,
    this.reactions = const {},
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderId: map['senderId']?.toString() ?? '',
      senderEmail: map['senderEmail']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
      seen: map['seen'] == true,
      type: map['type']?.toString() ?? 'text',
      replyToId: map['replyToId']?.toString(),
      replyToMessage: map['replyToMessage']?.toString(),
      replyToSenderId: map['replyToSenderId']?.toString(),
      reactions: (map['reactions'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'seen': seen,
      'type': type,
      'replyToId': replyToId,
      'replyToMessage': replyToMessage,
      'replyToSenderId': replyToSenderId,
      'reactions': reactions,
    };
  }
}
