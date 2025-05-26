import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/services/service_locator.dart';
import '../../../logic/cubit/group/group_cubit.dart';
import '../../../logic/cubit/group/group_state.dart';
import '../../../router/app_router.dart';
import '../../home/home_screen.dart';
import 'add_participants_screen.dart';
import 'edit_group_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;

  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late final GroupCubit _groupCubit;

  @override
  void initState() {
    super.initState();

    // Get current user ID from auth repository
    final currentUserId = getIt<AuthRepository>().currentUser?.uid ?? '';
    _groupCubit = getIt.get<GroupCubit>(param1: currentUserId);
    _groupCubit.getGroupById(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _groupCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Group Info'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<GroupCubit, GroupState>(
          listener: (context, state) {
            if (state.status == GroupStatus.error && state.error != null) {
              UiUtils.showSnackBar(context, message: state.error!);
            }
          },
          builder: (context, state) {
            if (state.status == GroupStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.selectedGroup == null) {
              return const Center(child: Text('Group not found'));
            }

            final group = state.selectedGroup!;
            final isAdmin = group.admins.contains(_groupCubit.currentUserId);
            final isCreator = group.createdBy == _groupCubit.currentUserId;

            return SingleChildScrollView(
              child: Column(
                children: [
                  // Group Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    color: Colors.grey[50],
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).primaryColorDark,
                          backgroundImage:
                              group.imageUrl != null
                                  ? NetworkImage(group.imageUrl!)
                                  : null,
                          child:
                              group.imageUrl == null
                                  ? Text(
                                    group.name.isNotEmpty
                                        ? group.name[0].toUpperCase()
                                        : 'G',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (group.description != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            group.description!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Created ${_formatDate(group.createdAt.toDate())}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  if (isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                getIt<AppRouter>().push(
                                  EditGroupScreen(group: group),
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Group'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                getIt<AppRouter>().push(
                                  AddParticipantsScreen(
                                    groupId: widget.groupId,
                                    existingParticipants: group.participants,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add People'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Participants Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${group.participants.length} Participants',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: group.participants.length,
                          itemBuilder: (context, index) {
                            final participantId = group.participants[index];
                            final participantName =
                                group.participantsName[participantId] ??
                                'Unknown';
                            final isParticipantAdmin = group.admins.contains(
                              participantId,
                            );
                            final isMe =
                                participantId == _groupCubit.currentUserId;
                            final isParticipantCreator =
                                participantId == group.createdBy;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).primaryColorDark,
                                foregroundImage: NetworkImage(
                                  "https://ui-avatars.com/api/?name=${Uri.encodeComponent(participantName)}&background=${Theme.of(context).primaryColorDark.value.toRadixString(16).substring(2)}&color=fff",
                                ),
                                child: Text(
                                  participantName.isNotEmpty
                                      ? participantName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isMe ? 'You' : participantName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isParticipantCreator)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Creator',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (isParticipantAdmin)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing:
                                  isAdmin && !isMe && !isParticipantCreator
                                      ? PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          switch (value) {
                                            case 'make_admin':
                                              await _groupCubit.makeAdmin(
                                                groupId: widget.groupId,
                                                userId: participantId,
                                              );
                                              break;
                                            case 'remove_admin':
                                              await _groupCubit.removeAdmin(
                                                groupId: widget.groupId,
                                                userId: participantId,
                                              );
                                              break;
                                            case 'remove':
                                              _showRemoveParticipantDialog(
                                                participantId,
                                                participantName,
                                              );
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) {
                                          List<PopupMenuEntry<String>> items =
                                              [];

                                          if (!isParticipantAdmin) {
                                            items.add(
                                              const PopupMenuItem(
                                                value: 'make_admin',
                                                child: Text('Make Admin'),
                                              ),
                                            );
                                          } else {
                                            items.add(
                                              const PopupMenuItem(
                                                value: 'remove_admin',
                                                child: Text('Remove Admin'),
                                              ),
                                            );
                                          }

                                          items.add(
                                            const PopupMenuItem(
                                              value: 'remove',
                                              child: Text(
                                                'Remove from Group',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          );

                                          return items;
                                        },
                                      )
                                      : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Danger Zone
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showLeaveGroupDialog(),
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Leave Group'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        if (isCreator) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showDeleteGroupDialog(),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('Delete Group'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showRemoveParticipantDialog(
    String participantId,
    String participantName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Remove Participant',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
                fontSize: 20,
              ),
            ),
            content: Text(
              'Are you sure you want to remove $participantName from the group?',
              style: const TextStyle(fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _groupCubit.removeParticipant(
                    groupId: widget.groupId,
                    participantId: participantId,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Leave Group',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
                fontSize: 20,
              ),
            ),
            content: const Text(
              'Are you sure you want to leave this group? You won\'t be able to see new messages.',
              style: TextStyle(fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _groupCubit.leaveGroup(widget.groupId);
                  // Navigate back to home screen
                  getIt<AppRouter>().pushAndRemoveUntil(const HomeScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Leave',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Delete Group',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 20,
              ),
            ),
            content: const Text(
              'Are you sure you want to delete this group? This action cannot be undone and all messages will be lost.',
              style: TextStyle(fontSize: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _groupCubit.deleteGroup(widget.groupId);
                  // Navigate back to home screen
                  getIt<AppRouter>().pushAndRemoveUntil(const HomeScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }
}
