import 'package:chatzilla/data/models/chat_message.dart';
import 'package:chatzilla/data/models/chat_room_model.dart';
import 'package:chatzilla/data/models/group_model.dart';
import 'package:chatzilla/data/models/user_model.dart';
import 'package:chatzilla/data/services/base_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'group_repository.dart';

class ChatRepository extends BaseRepository {
  CollectionReference get _chatRooms => firestore.collection("chatRooms");

  CollectionReference getChatRoomMessages(String chatRoomId) {
    return _chatRooms.doc(chatRoomId).collection("messages");
  }

  Future<ChatRoomModel> getOrCreateChatRoom(
    String currentUserId,
    String otherUserId,
  ) async {
    if (currentUserId == otherUserId) {
      throw Exception("Cannot create a chat room with yourself");
    }

    final users = [currentUserId, otherUserId]..sort();
    final roomId = users.join("_");

    final roomDoc = await _chatRooms.doc(roomId).get();

    if (roomDoc.exists) {
      return ChatRoomModel.fromFirestore(roomDoc);
    }

    final currentUserData =
        (await firestore.collection("users").doc(currentUserId).get()).data()
            as Map<String, dynamic>;
    final otherUserData =
        (await firestore.collection("users").doc(otherUserId).get()).data()
            as Map<String, dynamic>;
    final participantsName = {
      currentUserId: currentUserData['fullName']?.toString() ?? "",
      otherUserId: otherUserData['fullName']?.toString() ?? "",
    };

    final newRoom = ChatRoomModel(
      id: roomId,
      participants: users,
      participantsName: participantsName,
      lastReadTime: {
        currentUserId: Timestamp.now(),
        otherUserId: Timestamp.now(),
      },
    );

    await _chatRooms.doc(roomId).set(newRoom.toMap());
    return newRoom;
  }

  Future<void> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    final batch = firestore.batch();

    final messageRef = getChatRoomMessages(chatRoomId);
    final messageDoc = messageRef.doc();

    final message = ChatMessage(
      id: messageDoc.id,
      chatRoomId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      type: type,
      timestamp: Timestamp.now(),
      readBy: [senderId],
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
    );

    batch.set(messageDoc, message.toMap());

    batch.update(_chatRooms.doc(chatRoomId), {
      "lastMessage": content,
      "lastMessageSenderId": senderId,
      "lastMessageTime": message.timestamp,
    });
    await batch.commit();
  }

  // Send group message
  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String content,
    required String senderName,
    MessageType type = MessageType.text,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    try {
      final messageRef =
          firestore
              .collection('chatRooms')
              .doc(groupId)
              .collection('messages')
              .doc();

      final message = ChatMessage(
        id: messageRef.id,
        chatRoomId: groupId,
        senderId: senderId,
        receiverId: null, // No specific receiver for group messages
        content: content,
        type: type,
        status: MessageStatus.sent,
        timestamp: Timestamp.now(),
        readBy: [senderId], // Sender has read it by default
        replyToMessageId: replyToMessageId,
        replyToContent: replyToContent,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        chatType: ChatType.group,
        senderName: senderName,
      );

      await messageRef.set(message.toMap());

      // Update group's last message info
      final groupRepository = GroupRepository();
      await groupRepository.updateLastMessage(
        groupId: groupId,
        lastMessage: content,
        senderId: senderId,
      );

      // Update chat room's last message
      await _chatRooms.doc(groupId).update({
        'lastMessage': content,
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': senderId,
      });
    } catch (e) {
      throw Exception('Failed to send group message: $e');
    }
  }

  // Get group messages (similar to getMessages but for groups)
  Stream<List<ChatMessage>> getGroupMessages(
    String groupId, {
    DocumentSnapshot? lastDocument,
  }) {
    Query query = firestore
        .collection('chatRooms')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList(),
    );
  }

  // Get more group messages for pagination
  Future<List<ChatMessage>> getMoreGroupMessages(
    String groupId, {
    required DocumentSnapshot lastDocument,
  }) async {
    final query = firestore
        .collection('chatRooms')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDocument)
        .limit(20);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  Stream<List<ChatMessage>> getMessages(
    String chatRoomId, {
    DocumentSnapshot? lastDocument,
  }) {
    var query = getChatRoomMessages(
      chatRoomId,
    ).orderBy('timestamp', descending: true).limit(20);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList(),
    );
  }

  Future<List<ChatMessage>> getMoreMessages(
    String chatRoomId, {
    required DocumentSnapshot lastDocument,
  }) async {
    final query = getChatRoomMessages(chatRoomId)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDocument)
        .limit(20);
    print("comingg");
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  Stream<List<ChatRoomModel>> getChatRooms(String userId) {
    return _chatRooms
        .where("participants", arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatRoomModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Stream<int> getUnreadCount(String chatRoomId, String userId) {
    return getChatRoomMessages(chatRoomId)
        .where("receiverId", isEqualTo: userId)
        .where('status', isEqualTo: MessageStatus.sent.toString())
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Add this method around line 240
  Stream<int> getGroupUnreadCount(String groupId, String userId) {
    return firestore
        .collection('chatRooms')
        .doc(groupId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('readBy', whereNotIn: [userId])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      final batch = firestore.batch();

      final unreadMessages =
          await getChatRoomMessages(chatRoomId)
              .where("receiverId", isEqualTo: userId)
              .where('status', isEqualTo: MessageStatus.sent.toString())
              .get();
      print("found ${unreadMessages.docs.length} unread messages");

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
          'status': MessageStatus.read.toString(),
        });

        await batch.commit();

        print("Marked messaegs as read for user $userId");
      }
    } catch (e) {}
  }

  // Mark group messages as read
  Future<void> markGroupMessagesAsRead(String groupId, String userId) async {
    try {
      final messagesQuery = firestore
          .collection('chatRooms')
          .doc(groupId)
          .collection('messages')
          .where('readBy', whereNotIn: [userId])
          .limit(50); // Limit to avoid large operations

      final snapshot = await messagesQuery.get();

      final batch = firestore.batch();

      for (final doc in snapshot.docs) {
        final messageRef = doc.reference;
        batch.update(messageRef, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking group messages as read: $e');
    }
  }

  Stream<Map<String, dynamic>> getUserOnlineStatus(String userId) {
    return firestore.collection("users").doc(userId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      return {
        'isOnline': data?['isOnline'] ?? false,
        'lastSeen': data?['lastSeen'],
      };
    });
  }

  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await firestore.collection("users").doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': Timestamp.now(),
    });
  }

  Future<void> updateTypingStatus(
    String chatRoomId,
    String userId,
    bool isTyping,
  ) async {
    try {
      final doc = await _chatRooms.doc(chatRoomId).get();
      if (!doc.exists) {
        print("chat room does not exist");
        return;
      }
      await _chatRooms.doc(chatRoomId).update({
        'isTyping': isTyping,
        'typingUserId': isTyping ? userId : null,
      });
    } catch (e) {
      print("error updating typing status");
    }
  }

  // Update typing status for groups
  Future<void> updateGroupTypingStatus(
    String groupId,
    String userId,
    String userName,
    bool isTyping,
  ) async {
    try {
      final doc = await _chatRooms.doc(groupId).get();
      if (!doc.exists) {
        print("Group chat room does not exist");
        return;
      }

      await _chatRooms.doc(groupId).update({
        'isTyping': isTyping,
        'typingUserId': isTyping ? userId : null,
        'typingUserName': isTyping ? userName : null,
      });
    } catch (e) {
      print("error updating group typing status: $e");
    }
  }

  Stream<Map<String, dynamic>> getTypingStatus(String chatRoomId) {
    return _chatRooms.doc(chatRoomId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return {'isTyping': false, 'typingUserId': null};
      }
      final data = snapshot.data() as Map<String, dynamic>;
      return {
        "isTyping": data['isTyping'] ?? false,
        "typingUserId": data['typingUserId'],
      };
    });
  }

  // Get group typing status
  Stream<Map<String, dynamic>> getGroupTypingStatus(String groupId) {
    return _chatRooms.doc(groupId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return {
          'isTyping': false,
          'typingUserId': null,
          'typingUserName': null,
        };
      }
      final data = snapshot.data() as Map<String, dynamic>;
      return {
        "isTyping": data['isTyping'] ?? false,
        "typingUserId": data['typingUserId'],
        "typingUserName": data['typingUserName'],
      };
    });
  }

  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    final userRef = firestore.collection("users").doc(currentUserId);
    await userRef.update({
      'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
    });
  }

  Future<void> unBlockUser(String currentUserId, String blockedUserId) async {
    final userRef = firestore.collection("users").doc(currentUserId);
    await userRef.update({
      'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
    });
  }

  Stream<bool> isUserBlocked(String currentUserId, String otherUserId) {
    return firestore.collection("users").doc(currentUserId).snapshots().map((
      doc,
    ) {
      final userData = UserModel.fromFirestore(doc);
      return userData.blockedUsers.contains(otherUserId);
    });
  }

  Stream<bool> amIBlocked(String currentUserId, String otherUserId) {
    return firestore.collection("users").doc(otherUserId).snapshots().map((
      doc,
    ) {
      final userData = UserModel.fromFirestore(doc);
      return userData.blockedUsers.contains(currentUserId);
    });
  }

  // Get combined chat rooms (individual + groups)
  Stream<List<dynamic>> getAllChatRooms(String userId) {
    // Get individual chats
    final individualChatsStream = _chatRooms
        .where("participants", arrayContains: userId)
        .where("isGroup", isEqualTo: false)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatRoomModel.fromFirestore(doc))
                  .toList(),
        );

    // Get group chats
    final groupChatsStream = GroupRepository().getUserGroups(userId);

    // Combine both streams
    return Rx.combineLatest2(individualChatsStream, groupChatsStream, (
      List<ChatRoomModel> individualChats,
      List<GroupModel> groupChats,
    ) {
      // Convert to a common format and sort by last message time
      List<dynamic> allChats = [];

      allChats.addAll(individualChats);
      allChats.addAll(groupChats);

      // Sort by last message time
      allChats.sort((a, b) {
        Timestamp? timeA;
        Timestamp? timeB;

        if (a is ChatRoomModel) {
          timeA = a.lastMessageTime;
        } else if (a is GroupModel) {
          timeA = a.lastMessageTime;
        }

        if (b is ChatRoomModel) {
          timeB = b.lastMessageTime;
        } else if (b is GroupModel) {
          timeB = b.lastMessageTime;
        }

        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;

        return timeB.compareTo(timeA);
      });

      return allChats;
    });
  }
}
