import 'dart:async';

import 'package:chatzilla/data/models/group_model.dart';
import 'package:chatzilla/data/repositories/group_repository.dart';
import 'package:chatzilla/logic/cubit/group/groups_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GroupsCubit extends Cubit<GroupsState> {
  final GroupRepository _groupRepository;
  final String currentUserId;
  StreamSubscription? _groupsSubscription;

  GroupsCubit({
    required GroupRepository groupRepository,
    required this.currentUserId,
  })  : _groupRepository = groupRepository,
        super(const GroupsState());

  void loadGroups() {
    emit(state.copyWith(status: GroupsStatus.loading));
    
    _groupsSubscription?.cancel();
    _groupsSubscription = _groupRepository
        .getUserGroups(currentUserId)
        .listen(
          (groups) {
            emit(state.copyWith(
              status: GroupsStatus.loaded,
              groups: groups,
              error: null,
            ));
          },
          onError: (error) {
            emit(state.copyWith(
              status: GroupsStatus.error,
              error: "Failed to load groups: $error",
            ));
          },
        );
  }

  Future<void> createGroup({
    required String name,
    required String description,
    required List<String> members,
    String? groupImageUrl,
  }) async {
    try {
      // Add current user to members if not already included
      if (!members.contains(currentUserId)) {
        members.add(currentUserId);
      }

      await _groupRepository.createGroup(
        name: name,
        description: description,
        createdBy: currentUserId,
        members: members,
        groupImageUrl: groupImageUrl,
      );
    } catch (e) {
      emit(state.copyWith(error: "Failed to create group: $e"));
    }
  }

  Future<List<GroupModel>> searchGroups(String query) async {
    try {
      return await _groupRepository.searchGroups(query);
    } catch (e) {
      emit(state.copyWith(error: "Failed to search groups: $e"));
      return [];
    }
  }

  @override
  Future<void> close() {
    _groupsSubscription?.cancel();
    return super.close();
  }
}
