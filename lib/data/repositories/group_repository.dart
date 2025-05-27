import 'package:chatzilla/data/models/chat_message.dart';
import 'package:chatzilla/data/models/group_model.dart';
import 'package:chatzilla/data/services/base_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupRepository extends BaseRepository {
  CollectionReference get _groups => firestore.collection("groups");

  CollectionReference getGroupMessages(String groupId) {
    return _groups.doc(groupId).collection("messages");
  }

  // Create a new group
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required List<String> members,
    String? groupImageUrl,
  }) async {
    final groupDoc = _groups.doc();

    // Get creator's name and all member names
    final membersName = <String, String>{};

    for (String memberId in members) {
      final userDoc = await firestore.collection("users").doc(memberId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        membersName[memberId] = userData['fullName']?.toString() ?? "";
      }
    }

    final group = GroupModel(
      id: groupDoc.id,
      name: name,
      description: description,
      groupImageUrl: groupImageUrl,
      members: members,
      admins: [createdBy], // Creator is automatically admin
      createdBy: createdBy,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      membersName: membersName,
      lastReadTime: {for (String member in members) member: Timestamp.now()},
    );

    await groupDoc.set(group.toMap());

    // Send system message about group creation
    await sendSystemMessage(
      groupId: group.id,
      content: "${membersName[createdBy] ?? 'Someone'} created this group",
      senderId: createdBy,
    );

    return group;
  }

  // Get group by ID
  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (doc.exists) {
      return GroupModel.fromFirestore(doc);
    }
    return null;
  }

  // Get all groups for a user
  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _groups
        .where("members", arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => GroupModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Send message to group
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
    final batch = firestore.batch();

    final messageRef = getGroupMessages(groupId);
    final messageDoc = messageRef.doc();

    final message = ChatMessage(
      id: messageDoc.id,
      chatRoomId: groupId,
      senderId: senderId,
      receiverId: '', // Empty for group messages
      content: content,
      type: type,
      timestamp: Timestamp.now(),
      readBy: [senderId],
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      chatType: ChatType.group,
      senderName: senderName,
    );

    batch.set(messageDoc, message.toMap());

    batch.update(_groups.doc(groupId), {
      "lastMessage": content,
      "lastMessageSenderId": senderId,
      "lastMessageTime": message.timestamp,
      "updatedAt": message.timestamp,
    });

    await batch.commit();
  }

  // Send system message (for group events)
  Future<void> sendSystemMessage({
    required String groupId,
    required String content,
    required String senderId,
  }) async {
    final messageRef = getGroupMessages(groupId);
    final messageDoc = messageRef.doc();

    final message = ChatMessage(
      id: messageDoc.id,
      chatRoomId: groupId,
      senderId: senderId,
      receiverId: '',
      content: content,
      type: MessageType.systemMessage,
      timestamp: Timestamp.now(),
      readBy: [],
      chatType: ChatType.group,
    );

    await messageDoc.set(message.toMap());
  }

  // Get group messages
  Stream<List<ChatMessage>> getGroupMessagesStream(
    String groupId, {
    DocumentSnapshot? lastDocument,
  }) {
    var query = getGroupMessages(
      groupId,
    ).orderBy('timestamp', descending: true).limit(20);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList(),
    );
  }

  // Load more messages
  Future<List<ChatMessage>> getMoreGroupMessages(
    String groupId, {
    required DocumentSnapshot lastDocument,
  }) async {
    final query = getGroupMessages(groupId)
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDocument)
        .limit(20);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
  }

  // Add member to group
  Future<void> addMemberToGroup({
    required String groupId,
    required String memberId,
    required String addedBy,
  }) async {
    final batch = firestore.batch();

    // Get member's name
    final userDoc = await firestore.collection("users").doc(memberId).get();
    final userData = userDoc.data() as Map<String, dynamic>;
    final memberName = userData['fullName']?.toString() ?? "";

    // Get group to check current members
    final groupDoc = await _groups.doc(groupId).get();
    final groupData = groupDoc.data() as Map<String, dynamic>;
    final currentMembers = List<String>.from(groupData['members']);

    if (!currentMembers.contains(memberId)) {
      // Add member to group
      batch.update(_groups.doc(groupId), {
        'members': FieldValue.arrayUnion([memberId]),
        'membersName.$memberId': memberName,
        'lastReadTime.$memberId': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      await batch.commit();

      // Send system message
      final adderDoc = await firestore.collection("users").doc(addedBy).get();
      final adderData = adderDoc.data() as Map<String, dynamic>;
      final adderName = adderData['fullName']?.toString() ?? "";

      await sendSystemMessage(
        groupId: groupId,
        content: "$adderName added $memberName",
        senderId: addedBy,
      );
    }
  }

  // Remove member from group
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String memberId,
    required String removedBy,
  }) async {
    final batch = firestore.batch();

    // Get member's name before removing
    final userDoc = await firestore.collection("users").doc(memberId).get();
    final userData = userDoc.data() as Map<String, dynamic>;
    final memberName = userData['fullName']?.toString() ?? "";

    // Remove member from group
    batch.update(_groups.doc(groupId), {
      'members': FieldValue.arrayRemove([memberId]),
      'admins': FieldValue.arrayRemove([
        memberId,
      ]), // Also remove from admins if present
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();

    // Send system message
    final removerDoc = await firestore.collection("users").doc(removedBy).get();
    final removerData = removerDoc.data() as Map<String, dynamic>;
    final removerName = removerData['fullName']?.toString() ?? "";

    await sendSystemMessage(
      groupId: groupId,
      content: "$removerName removed $memberName",
      senderId: removedBy,
    );
  }

  // Leave group
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final batch = firestore.batch();

    // Get user's name
    final userDoc = await firestore.collection("users").doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>;
    final userName = userData['fullName']?.toString() ?? "";

    // Remove user from group
    batch.update(_groups.doc(groupId), {
      'members': FieldValue.arrayRemove([userId]),
      'admins': FieldValue.arrayRemove([userId]),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();

    // Send system message
    await sendSystemMessage(
      groupId: groupId,
      content: "$userName left the group",
      senderId: userId,
    );
  }

  // Make member admin
  Future<void> makeAdmin({
    required String groupId,
    required String memberId,
    required String promotedBy,
  }) async {
    final batch = firestore.batch();

    // Add to admins array
    batch.update(_groups.doc(groupId), {
      'admins': FieldValue.arrayUnion([memberId]),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();

    // Send system message
    final memberDoc = await firestore.collection("users").doc(memberId).get();
    final memberData = memberDoc.data() as Map<String, dynamic>;
    final memberName = memberData['fullName']?.toString() ?? "";

    await sendSystemMessage(
      groupId: groupId,
      content: "$memberName is now an admin",
      senderId: promotedBy,
    );
  }

  // Remove admin privileges
  Future<void> removeAdmin({
    required String groupId,
    required String memberId,
    required String removedBy,
  }) async {
    final batch = firestore.batch();

    // Remove from admins array
    batch.update(_groups.doc(groupId), {
      'admins': FieldValue.arrayRemove([memberId]),
      'updatedAt': Timestamp.now(),
    });

    await batch.commit();

    // Send system message
    final memberDoc = await firestore.collection("users").doc(memberId).get();
    final memberData = memberDoc.data() as Map<String, dynamic>;
    final memberName = memberData['fullName']?.toString() ?? "";

    await sendSystemMessage(
      groupId: groupId,
      content: "$memberName is no longer an admin",
      senderId: removedBy,
    );
  }

  // Update group info
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? groupImageUrl,
  }) async {
    final updates = <String, dynamic>{'updatedAt': Timestamp.now()};

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (groupImageUrl != null) updates['groupImageUrl'] = groupImageUrl;

    await _groups.doc(groupId).update(updates);
  }

  // Update group settings
  Future<void> updateGroupSettings({
    required String groupId,
    required GroupSettings settings,
  }) async {
    await _groups.doc(groupId).update({
      'settings': settings.toMap(),
      'updatedAt': Timestamp.now(),
    });
  }

  // Mark messages as read for a user
  Future<void> markGroupMessagesAsRead(String groupId, String userId) async {
    try {
      final batch = firestore.batch();

      // Get the group to know all members
      final groupDoc = await _groups.doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final groupMembers = List<String>.from(groupData['members'] ?? []);

      // Get all messages not sent by this user that they haven't read yet
      final unreadMessages =
          await getGroupMessages(
            groupId,
          ).where('senderId', isNotEqualTo: userId).get();

      // Filter messages where userId is not in readBy array
      for (final doc in unreadMessages.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final readBy = List<String>.from(data['readBy'] ?? []);
        final senderId = data['senderId'] as String;

        if (!readBy.contains(userId)) {
          // Add this user to readBy array
          final updatedReadBy = [...readBy, userId];

          // Check if all group members (except sender) have now read the message
          final otherMembers =
              groupMembers.where((member) => member != senderId).toList();
          final isReadByAll = otherMembers.every(
            (member) => updatedReadBy.contains(member),
          );

          final updateData = <String, dynamic>{
            'readBy': FieldValue.arrayUnion([userId]),
          };

          // If all members have read it, update status to read
          if (isReadByAll) {
            updateData['status'] = MessageStatus.read.toString();
          }

          batch.update(doc.reference, updateData);
        }
      }

      // Update last read time
      batch.update(_groups.doc(groupId), {
        'lastReadTime.$userId': Timestamp.now(),
      });

      await batch.commit();
    } catch (e) {
      print("Error marking group messages as read: $e");
    }
  }

  // Get unread count for group
  Stream<int> getGroupUnreadCount(String groupId, String userId) {
    return getGroupMessages(groupId)
        .where('senderId', isNotEqualTo: userId)
        .where('readBy', whereNotIn: [userId])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Update typing status
  Future<void> updateGroupTypingStatus(
    String groupId,
    String userId,
    bool isTyping,
  ) async {
    try {
      await _groups.doc(groupId).update({
        'isTyping': isTyping,
        'typingUserId': isTyping ? userId : null,
      });
    } catch (e) {
      print("Error updating group typing status: $e");
    }
  }

  // Get typing status
  Stream<Map<String, dynamic>> getGroupTypingStatus(String groupId) {
    return _groups.doc(groupId).snapshots().map((snapshot) {
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

  // Search groups by name
  Future<List<GroupModel>> searchGroups(String query) async {
    final snapshot =
        await _groups
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

    return snapshot.docs.map((doc) => GroupModel.fromFirestore(doc)).toList();
  }
}
