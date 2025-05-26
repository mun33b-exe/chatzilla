import 'package:equatable/equatable.dart';
import '../../../data/models/group_model.dart';

enum GroupStatus { initial, loading, loaded, error }

class GroupState extends Equatable {
  final GroupStatus status;
  final String? error;
  final List<GroupModel> groups;
  final GroupModel? selectedGroup;
  final bool isCreating;
  final bool isUpdating;
  final String? createdGroupId;

  const GroupState({
    this.status = GroupStatus.initial,
    this.error,
    this.groups = const [],
    this.selectedGroup,
    this.isCreating = false,
    this.isUpdating = false,
    this.createdGroupId,
  });

  GroupState copyWith({
    GroupStatus? status,
    String? error,
    List<GroupModel>? groups,
    GroupModel? selectedGroup,
    bool? isCreating,
    bool? isUpdating,
    String? createdGroupId,
    bool clearError = false,
    bool clearSelectedGroup = false,
    bool clearCreatedGroupId = false,
  }) {
    return GroupState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      groups: groups ?? this.groups,
      selectedGroup:
          clearSelectedGroup ? null : (selectedGroup ?? this.selectedGroup),
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      createdGroupId:
          clearCreatedGroupId ? null : (createdGroupId ?? this.createdGroupId),
    );
  }

  @override
  List<Object?> get props => [
    status,
    error,
    groups,
    selectedGroup,
    isCreating,
    isUpdating,
    createdGroupId,
  ];
}
