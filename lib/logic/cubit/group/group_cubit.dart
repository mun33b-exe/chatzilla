import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/models/group_model.dart';
import 'group_state.dart';

class GroupCubit extends Cubit<GroupState> {
  final GroupRepository _groupRepository;
  final String currentUserId;
  StreamSubscription<List<GroupModel>>? _groupsSubscription;

  GroupCubit({
    required GroupRepository groupRepository,
    required this.currentUserId,
  }) : _groupRepository = groupRepository,
       super(const GroupState());

  // Load user's groups
  void loadUserGroups() {
    try {
      emit(state.copyWith(status: GroupStatus.loading));

      _groupsSubscription?.cancel();

      _groupsSubscription = _groupRepository
          .getUserGroups(currentUserId)
          .listen(
            (groups) {
              emit(
                state.copyWith(
                  status: GroupStatus.loaded,
                  groups: groups,
                  clearError: true,
                ),
              );
            },
            onError: (error) {
              emit(
                state.copyWith(
                  status: GroupStatus.error,
                  error: 'Failed to load groups: $error',
                ),
              );
            },
          );
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupStatus.error,
          error: 'Failed to load groups: $e',
        ),
      );
    }
  }

  // Create a new group
  Future<void> createGroup({
    required String name,
    String? description,
    String? imageUrl,
    required List<String> participants,
    required Map<String, String> participantsName,
  }) async {
    try {
      emit(state.copyWith(isCreating: true, clearError: true));

      print('GroupCubit: Starting group creation...');
      print('GroupCubit: Name: $name');
      print('GroupCubit: Participants: $participants');
      print('GroupCubit: ParticipantsName: $participantsName');
      print('GroupCubit: CurrentUserId: $currentUserId');

      // Validate current user ID
      if (currentUserId.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Validate input
      if (name.trim().isEmpty) {
        throw Exception('Group name is required');
      }

      if (participants.isEmpty) {
        throw Exception('At least one participant is required');
      }

      if (!participants.contains(currentUserId)) {
        throw Exception('Current user must be included in participants');
      }

      // Validate all participants have names
      for (final participantId in participants) {
        if (!participantsName.containsKey(participantId) ||
            participantsName[participantId]!.trim().isEmpty) {
          throw Exception('All participants must have names');
        }
      }

      print('GroupCubit: Validation passed, calling repository...');

      final groupId = await _groupRepository.createGroup(
        name: name,
        description: description,
        imageUrl: imageUrl,
        createdBy: currentUserId,
        participants: participants,
        participantsName: participantsName,
      );

      print('GroupCubit: Group created with ID: $groupId');

      emit(state.copyWith(isCreating: false, createdGroupId: groupId));
    } catch (e) {
      print('GroupCubit: Error creating group: $e');
      emit(
        state.copyWith(isCreating: false, error: 'Failed to create group: $e'),
      );
    }
  }

  // Get specific group details
  Future<void> getGroupById(String groupId) async {
    try {
      emit(state.copyWith(status: GroupStatus.loading));

      final group = await _groupRepository.getGroupById(groupId);

      if (group != null) {
        emit(
          state.copyWith(
            status: GroupStatus.loaded,
            selectedGroup: group,
            clearError: true,
          ),
        );
      } else {
        emit(
          state.copyWith(status: GroupStatus.error, error: 'Group not found'),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupStatus.error,
          error: 'Failed to get group: $e',
        ),
      );
    }
  }

  // Add participants to group
  Future<void> addParticipants({
    required String groupId,
    required List<String> newParticipants,
    required Map<String, String> newParticipantsName,
  }) async {
    try {
      emit(state.copyWith(isUpdating: true, clearError: true));

      await _groupRepository.addParticipants(
        groupId: groupId,
        newParticipants: newParticipants,
        newParticipantsName: newParticipantsName,
      );

      emit(state.copyWith(isUpdating: false));

      // Refresh the specific group data
      await getGroupById(groupId);
    } catch (e) {
      emit(
        state.copyWith(
          isUpdating: false,
          error: 'Failed to add participants: $e',
        ),
      );
    }
  }

  // Remove participant from group
  Future<void> removeParticipant({
    required String groupId,
    required String participantId,
  }) async {
    try {
      emit(state.copyWith(isUpdating: true, clearError: true));

      await _groupRepository.removeParticipant(
        groupId: groupId,
        participantId: participantId,
      );

      emit(state.copyWith(isUpdating: false));

      // Refresh the specific group data
      await getGroupById(groupId);
    } catch (e) {
      emit(
        state.copyWith(
          isUpdating: false,
          error: 'Failed to remove participant: $e',
        ),
      );
    }
  }

  // Update group information
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? imageUrl,
  }) async {
    try {
      emit(state.copyWith(isUpdating: true, clearError: true));

      await _groupRepository.updateGroupInfo(
        groupId: groupId,
        name: name,
        description: description,
        imageUrl: imageUrl,
      );

      emit(state.copyWith(isUpdating: false));

      // Refresh the specific group data
      await getGroupById(groupId);
    } catch (e) {
      emit(
        state.copyWith(isUpdating: false, error: 'Failed to update group: $e'),
      );
    }
  }

  // Make user admin
  Future<void> makeAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      emit(state.copyWith(isUpdating: true, clearError: true));

      await _groupRepository.makeAdmin(groupId: groupId, userId: userId);

      emit(state.copyWith(isUpdating: false));

      // Refresh the specific group data
      await getGroupById(groupId);
    } catch (e) {
      emit(
        state.copyWith(isUpdating: false, error: 'Failed to make admin: $e'),
      );
    }
  }

  // Remove admin privileges
  Future<void> removeAdmin({
    required String groupId,
    required String userId,
  }) async {
    try {
      emit(state.copyWith(isUpdating: true, clearError: true));

      await _groupRepository.removeAdmin(groupId: groupId, userId: userId);

      emit(state.copyWith(isUpdating: false));

      // Refresh the specific group data
      await getGroupById(groupId);
    } catch (e) {
      emit(
        state.copyWith(isUpdating: false, error: 'Failed to remove admin: $e'),
      );
    }
  }

  // Leave group (remove current user)
  Future<void> leaveGroup(String groupId) async {
    try {
      emit(state.copyWith(isUpdating: true, clearError: true));

      await _groupRepository.removeParticipant(
        groupId: groupId,
        participantId: currentUserId,
      );

      emit(state.copyWith(isUpdating: false));

      // Remove from local state
      final updatedGroups = state.groups.where((g) => g.id != groupId).toList();
      emit(state.copyWith(groups: updatedGroups));
    } catch (e) {
      emit(
        state.copyWith(isUpdating: false, error: 'Failed to leave group: $e'),
      );
    }
  }

  // Delete group (only creator can delete)
  Future<void> deleteGroup(String groupId) async {
    try {
      emit(state.copyWith(isUpdating: true, clearError: true));

      await _groupRepository.deleteGroup(groupId);

      emit(state.copyWith(isUpdating: false));

      // Remove from local state
      final updatedGroups = state.groups.where((g) => g.id != groupId).toList();
      emit(state.copyWith(groups: updatedGroups));
    } catch (e) {
      emit(
        state.copyWith(isUpdating: false, error: 'Failed to delete group: $e'),
      );
    }
  }

  // Clear selected group
  void clearSelectedGroup() {
    emit(state.copyWith(clearSelectedGroup: true));
  }

  // Clear error
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  // Clear created group ID
  void clearCreatedGroupId() {
    emit(state.copyWith(clearCreatedGroupId: true));
  }

  @override
  Future<void> close() {
    _groupsSubscription?.cancel();
    return super.close();
  }
}
