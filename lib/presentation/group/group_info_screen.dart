import 'package:chatzilla/data/models/group_model.dart';
import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/group_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/presentation/group/add_members_screen.dart';
import 'package:chatzilla/presentation/group/edit_group_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GroupInfoScreen extends StatefulWidget {
  final GroupModel group;
  final String? currentUserId;

  const GroupInfoScreen({super.key, required this.group, this.currentUserId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late GroupModel _group;
  final String _currentUserId = getIt<AuthRepository>().currentUser?.uid ?? "";
  final GroupRepository _groupRepository = getIt<GroupRepository>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  bool get _isAdmin => _group.isAdmin(_currentUserId);
  bool get _isCreator => _group.isCreator(_currentUserId);
  bool get _canEditInfo =>
      _isAdmin && (_group.settings.onlyAdminsCanEditInfo ? _isAdmin : true);
  bool get _canAddMembers =>
      _group.settings.onlyAdminsCanAddMembers ? _isAdmin : true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        title: Text(
          'Group Info',
          style: TextStyle(
            color: Theme.of(context).scaffoldBackgroundColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'edit_group':
                  await _navigateToEditGroup();
                  break;
                case 'add_members':
                  await _navigateToAddMembers();
                  break;
                case 'leave_group':
                  await _showLeaveGroupDialog();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  if (_canEditInfo)
                    const PopupMenuItem<String>(
                      value: 'edit_group',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 12),
                          Text('Edit Group'),
                        ],
                      ),
                    ),
                  if (_canAddMembers)
                    const PopupMenuItem<String>(
                      value: 'add_members',
                      child: Row(
                        children: [
                          Icon(Icons.person_add),
                          SizedBox(width: 12),
                          Text('Add Members'),
                        ],
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'leave_group',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Leave Group',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _refreshGroupInfo,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGroupHeader(),
                      const SizedBox(height: 24),
                      _buildGroupActions(),
                      const SizedBox(height: 24),
                      _buildMembersSection(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildGroupHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Theme.of(context).primaryColorDark,
              foregroundImage:
                  _group.groupImageUrl != null
                      ? NetworkImage(_group.groupImageUrl!)
                      : null,
              child: Text(
                _group.name.isNotEmpty ? _group.name[0].toUpperCase() : "G",
                style: TextStyle(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _group.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_group.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _group.description,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${_group.members.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Members',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${_group.admins.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Admins',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      DateFormat(
                        'MMM dd, yyyy',
                      ).format(_group.createdAt.toDate()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Created',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupActions() {
    return Card(
      child: Column(
        children: [
          if (_canEditInfo)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Group Info'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _navigateToEditGroup,
            ),
          if (_canAddMembers)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add Members'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _navigateToAddMembers,
            ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              'Leave Group',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _showLeaveGroupDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Members (${_group.members.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_canAddMembers)
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: _navigateToAddMembers,
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _group.members.length,
            itemBuilder: (context, index) {
              final memberId = _group.members[index];
              final memberName =
                  _group.membersName?[memberId] ?? 'Unknown User';
              final isAdmin = _group.isAdmin(memberId);
              final isCreator = _group.isCreator(memberId);
              final isCurrentUser = memberId == _currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColorDark,
                  child: Text(
                    memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isCurrentUser ? 'You' : memberName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (isCreator)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColorDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Creator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColorDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: _buildMemberActions(
                  memberId,
                  isCurrentUser,
                  isAdmin,
                  isCreator,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget? _buildMemberActions(
    String memberId,
    bool isCurrentUser,
    bool isMemberAdmin,
    bool isMemberCreator,
  ) {
    if (isCurrentUser || !_isAdmin || isMemberCreator) {
      return null;
    }

    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'make_admin':
            await _makeAdmin(memberId);
            break;
          case 'remove_admin':
            await _removeAdmin(memberId);
            break;
          case 'remove_member':
            await _removeMember(memberId);
            break;
        }
      },
      itemBuilder:
          (context) => [
            if (!isMemberAdmin)
              const PopupMenuItem<String>(
                value: 'make_admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings),
                    SizedBox(width: 8),
                    Text('Make Admin'),
                  ],
                ),
              ),
            if (isMemberAdmin && _isCreator)
              const PopupMenuItem<String>(
                value: 'remove_admin',
                child: Row(
                  children: [
                    Icon(Icons.remove_moderator),
                    SizedBox(width: 8),
                    Text('Remove Admin'),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'remove_member',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
    );
  }

  Future<void> _refreshGroupInfo() async {
    try {
      final updatedGroup = await _groupRepository.getGroup(_group.id);
      if (updatedGroup != null) {
        setState(() {
          _group = updatedGroup;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh group info: $e')),
        );
      }
    }
  }

  Future<void> _navigateToEditGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditGroupScreen(group: _group)),
    );

    if (result == true) {
      await _refreshGroupInfo();
    }
  }

  Future<void> _navigateToAddMembers() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddMembersScreen(group: _group)),
    );

    if (result == true) {
      await _refreshGroupInfo();
    }
  }

  Future<void> _makeAdmin(String memberId) async {
    setState(() => _isLoading = true);
    try {
      await _groupRepository.makeAdmin(
        groupId: _group.id,
        memberId: memberId,
        promotedBy: _currentUserId,
      );
      await _refreshGroupInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member promoted to admin')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to make admin: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeAdmin(String memberId) async {
    setState(() => _isLoading = true);
    try {
      await _groupRepository.removeAdmin(
        groupId: _group.id,
        memberId: memberId,
        removedBy: _currentUserId,
      );
      await _refreshGroupInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin privileges removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove admin: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String memberId) async {
    final memberName = _group.membersName?[memberId] ?? 'this member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Member'),
            content: Text(
              'Are you sure you want to remove $memberName from the group?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _groupRepository.removeMemberFromGroup(
          groupId: _group.id,
          memberId: memberId,
          removedBy: _currentUserId,
        );
        await _refreshGroupInfo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$memberName removed from group')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove member: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showLeaveGroupDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Leave Group'),
            content: const Text('Are you sure you want to leave this group?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _groupRepository.leaveGroup(
          groupId: _group.id,
          userId: _currentUserId,
        );
        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the group')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to leave group: $e')));
        }
        setState(() => _isLoading = false);
      }
    }
  }
}
