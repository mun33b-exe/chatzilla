import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';

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
    print('GroupRepository: Starting createGroup...');
    print('GroupRepository: Name: $name');
    print('GroupRepository: CreatedBy: $createdBy');
    print('GroupRepository: Participants: $participants');
    print('GroupRepository: ParticipantsName: $participantsName');

    // Validate input parameters
    if (name.trim().isEmpty) {
      throw Exception('Group name cannot be empty');
    }
    if (name.trim().length < 3) {
      throw Exception('Group name must be at least 3 characters');
    }
    if (createdBy.isEmpty) {
      throw Exception('Creator ID cannot be empty');
    }
    if (participants.isEmpty) {
      throw Exception('Group must have at least one participant');
    }
    if (!participants.contains(createdBy)) {
      throw Exception('Creator must be included in participants');
    }

    // Validate participants have names
    for (final participantId in participants) {
      if (!participantsName.containsKey(participantId) ||
          participantsName[participantId]!.trim().isEmpty) {
        throw Exception('All participants must have valid names');
      }
    }

    try {
      print('GroupRepository: Creating Firestore references...');
      final groupRef = _firestore.collection('groups').doc();
      final now = Timestamp.now();

      final group = GroupModel(
        id: groupRef.id,
        name: name.trim(),
        description: description?.trim(),
        imageUrl: imageUrl,
        createdBy: createdBy,
        participants: participants,
        admins: [createdBy], // Creator is admin by default
        createdAt: now,
        participantsName: participantsName,
      );

      print('GroupRepository: Group model created: ${group.toMap()}');
      print('GroupRepository: groupRef.id: ${groupRef.id}');

      // Use transaction to ensure atomic operation
      print('GroupRepository: Starting Firestore transaction...');
      await _firestore.runTransaction((transaction) async {
        print(
          'GroupRepository: Inside transaction - creating group document...',
        );
        // Create group document
        transaction.set(groupRef, group.toMap());

        // Create group chat room
        print('GroupRepository: Creating chat room...');
        final chatRoomRef = _firestore.collection('chatRooms').doc(groupRef.id);
        transaction.set(chatRoomRef, {
          'groupId': groupRef.id,
          'participants': participants,
          'participantsName': participantsName,
          'isGroup': true,
          'createdAt': now,
          'lastMessage': null,
          'lastMessageTime': null,
          'lastMessageSenderId': null,
        });
        print('GroupRepository: Transaction operations completed');
      });

      print('GroupRepository: Transaction completed successfully');
      print('GroupRepository: Returning groupId: ${groupRef.id}');

      return groupRef.id;
    } catch (e) {
      print('GroupRepository: Error in createGroup: $e');
      print('GroupRepository: Error type: ${e.runtimeType}');
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
    // Validate input
    if (groupId.isEmpty) {
      throw Exception('Group ID cannot be empty');
    }
    if (newParticipants.isEmpty) {
      throw Exception('Must add at least one participant');
    }

    // Validate all new participants have names
    for (final participantId in newParticipants) {
      if (!newParticipantsName.containsKey(participantId) ||
          newParticipantsName[participantId]!.trim().isEmpty) {
        throw Exception('All participants must have valid names');
      }
    }

    try {
      // Use transaction to ensure atomic operation
      await _firestore.runTransaction((transaction) async {
        // Get current group data
        final groupRef = _firestore.collection('groups').doc(groupId);
        final groupDoc = await transaction.get(groupRef);

        if (!groupDoc.exists) {
          throw Exception('Group not found');
        }

        final currentGroup = GroupModel.fromFirestore(groupDoc);

        // Merge participant names (preserve existing ones, add new ones)
        final updatedParticipantsName = Map<String, String>.from(
          currentGroup.participantsName,
        );
        updatedParticipantsName.addAll(newParticipantsName);

        // Update group document
        transaction.update(groupRef, {
          'participants': FieldValue.arrayUnion(newParticipants),
          'participantsName': updatedParticipantsName,
        });

        // Update chat room participants
        final chatRoomRef = _firestore.collection('chatRooms').doc(groupId);
        transaction.update(chatRoomRef, {
          'participants': FieldValue.arrayUnion(newParticipants),
        });
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
    // Validate input
    if (groupId.isEmpty) {
      throw Exception('Group ID cannot be empty');
    }
    if (participantId.isEmpty) {
      throw Exception('Participant ID cannot be empty');
    }

    try {
      // Use transaction to ensure atomic operation
      await _firestore.runTransaction((transaction) async {
        final groupRef = _firestore.collection('groups').doc(groupId);
        final groupDoc = await transaction.get(groupRef);

        if (!groupDoc.exists) {
          throw Exception('Group not found');
        }

        final group = GroupModel.fromFirestore(groupDoc);

        // Check if participant is in the group
        if (!group.participants.contains(participantId)) {
          throw Exception('Participant is not in this group');
        }

        // Check if this is the last participant
        if (group.participants.length <= 1) {
          throw Exception('Cannot remove the last participant from group');
        }

        // Check if removing the creator (only creator can remove themselves)
        if (group.createdBy == participantId && group.participants.length > 1) {
          // Transfer ownership to another admin or first participant
          final newCreator = group.admins.firstWhere(
            (admin) => admin != participantId,
            orElse:
                () => group.participants.firstWhere((p) => p != participantId),
          );
          transaction.update(groupRef, {'createdBy': newCreator});
        }

        // Update participants name map
        final updatedParticipantsName = Map<String, String>.from(
          group.participantsName,
        );
        updatedParticipantsName.remove(participantId);

        // Update group document
        transaction.update(groupRef, {
          'participants': FieldValue.arrayRemove([participantId]),
          'admins': FieldValue.arrayRemove([participantId]),
          'participantsName': updatedParticipantsName,
        });

        // Update chat room participants
        final chatRoomRef = _firestore.collection('chatRooms').doc(groupId);
        transaction.update(chatRoomRef, {
          'participants': FieldValue.arrayRemove([participantId]),
        });
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
