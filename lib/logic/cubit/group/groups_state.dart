import 'package:chatzilla/data/models/group_model.dart';
import 'package:equatable/equatable.dart';

enum GroupsStatus { initial, loading, loaded, error }

class GroupsState extends Equatable {
  final GroupsStatus status;
  final String? error;
  final List<GroupModel> groups;

  const GroupsState({
    this.status = GroupsStatus.initial,
    this.error,
    this.groups = const [],
  });

  GroupsState copyWith({
    GroupsStatus? status,
    String? error,
    List<GroupModel>? groups,
  }) {
    return GroupsState(
      status: status ?? this.status,
      error: error ?? this.error,
      groups: groups ?? this.groups,
    );
  }

  @override
  List<Object?> get props => [status, error, groups];
}
