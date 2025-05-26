import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video }

enum MessageStatus { sent, read }

enum ChatType { individual, group }

class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String? receiverId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final Timestamp timestamp;
  final List<String> readBy;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderId;
  final String? replyToSenderName;
  final ChatType chatType;
  final String? senderName;

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    this.receiverId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.timestamp,
    required this.readBy,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderId,
    this.replyToSenderName,
    this.chatType = ChatType.individual,
    this.senderName,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      chatRoomId: data['chatRoomId'] as String,
      senderId: data['senderId'] as String,
      receiverId: data['receiverId'] as String?,
      content: data['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => MessageStatus.sent,
      ),
      timestamp: data['timestamp'] as Timestamp,
      readBy: List<String>.from(data['readBy'] ?? []),
      replyToMessageId: data['replyToMessageId'] as String?,
      replyToContent: data['replyToContent'] as String?,
      replyToSenderId: data['replyToSenderId'] as String?,
      replyToSenderName: data['replyToSenderName'] as String?,
      chatType: ChatType.values.firstWhere(
        (e) => e.toString() == data['chatType'],
        orElse: () => ChatType.individual,
      ),
      senderName: data['senderName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "chatRoomId": chatRoomId,
      "senderId": senderId,
      "receiverId": receiverId,
      "content": content,
      "type": type.toString(),
      "status": status.toString(),
      "timestamp": timestamp,
      "readBy": readBy,
      "replyToMessageId": replyToMessageId,
      "replyToContent": replyToContent,
      "replyToSenderId": replyToSenderId,
      "replyToSenderName": replyToSenderName,
      "chatType": chatType.toString(),
      "senderName": senderName,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? chatRoomId,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    Timestamp? timestamp,
    List<String>? readBy,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
    String? replyToSenderName,
    ChatType? chatType,
    String? senderName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      chatType: chatType ?? this.chatType,
      senderName: senderName ?? this.senderName,
    );
  }
}
