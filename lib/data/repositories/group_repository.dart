import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';

class GroupRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new group
  Future<String> createGroup({
    required String name,
    String? description,
    String? imageUrl,
    required String createdBy,
    required List<String> participants,
    required Map<String, String> participantsName,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc();

      final group = GroupModel(
        id: groupRef.id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        createdBy: createdBy,
        participants: participants,
        admins: [createdBy], // Creator is admin by default
        createdAt: Timestamp.now(),
        participantsName: participantsName,
      );

      await groupRef.set(group.toMap());

      // Create group chat room
      await _firestore.collection('chatRooms').doc(groupRef.id).set({
        'groupId': groupRef.id,
        'participants': participants,
        'isGroup': true,
        'createdAt': Timestamp.now(),
        'lastMessage': null,
        'lastMessageTime': null,
        'lastMessageSenderId': null,
      });

      return groupRef.id;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  // Get all groups for a user
  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('participants', arrayContains: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => GroupModel.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get group by ID
  Future<GroupModel?> getGroupById(String groupId) async {
    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        return GroupModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get group: $e');
    }
  }

  // Add participants to group
  Future<void> addParticipants({
    required String groupId,
    required List<String> newParticipants,
    required Map<String, String> newParticipantsName,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'participants': FieldValue.arrayUnion(newParticipants),
        'participantsName': newParticipantsName,
      });

      // Update chat room participants
      await _firestore.collection('chatRooms').doc(groupId).update({
        'participants': FieldValue.arrayUnion(newParticipants),
      });
    } catch (e) {
      throw Exception('Failed to add participants: $e');
    }
  }

  // Remove participant from group
  Future<void> removeParticipant({
    required String groupId,
    required String participantId,
  }) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final group = GroupModel.fromFirestore(groupDoc);

      Map<String, String> updatedParticipantsName = Map.from(
        group.participantsName,
      );
      updatedParticipantsName.remove(participantId);

      await _firestore.collection('groups').doc(groupId).update({
        'participants': FieldValue.arrayRemove([participantId]),
        'admins': FieldValue.arrayRemove([participantId]),
        'participantsName': updatedParticipantsName,
      });

      // Update chat room participants
      await _firestore.collection('chatRooms').doc(groupId).update({
        'participants': FieldValue.arrayRemove([participantId]),
      });
    } catch (e) {
      throw Exception('Failed to remove participant: $e');
    }
  }

  // Update group info
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('groups').doc(groupId).update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update group info: $e');
    }
  }

  // Make user admin
  Future<void> makeAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'admins': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Failed to make admin: $e');
    }
  }

  // Remove admin
  Future<void> removeAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'admins': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to remove admin: $e');
    }
  }

  // Delete group (only creator can delete)
  Future<void> deleteGroup(String groupId) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to delete group: $e');
    }
  }

  // Update last message info
  Future<void> updateLastMessage({
    required String groupId,
    required String lastMessage,
    required String senderId,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': senderId,
      });
    } catch (e) {
      throw Exception('Failed to update last message: $e');
    }
  }
}
