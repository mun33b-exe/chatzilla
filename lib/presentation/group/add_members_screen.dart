import 'package:chatzilla/data/models/group_model.dart';
import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/repositories/group_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:flutter/material.dart';

class AddMembersScreen extends StatefulWidget {
  final GroupModel group;

  const AddMembersScreen({super.key, required this.group});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final ContactRepository _contactRepository = getIt<ContactRepository>();
  final GroupRepository _groupRepository = getIt<GroupRepository>();
  final String _currentUserId = getIt<AuthRepository>().currentUser?.uid ?? "";

  List<Map<String, dynamic>> _contacts = [];
  Set<String> _selectedMembers = {};
  bool _isLoading = false;
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _contactRepository.getRegisteredContacts().timeout(
        const Duration(seconds: 10),
      );

      // Filter out contacts who are already members of the group
      final filteredContacts =
          contacts.where((contact) {
            return !widget.group.members.contains(contact['id']);
          }).toList();

      if (mounted) {
        setState(() {
          _contacts = filteredContacts;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load contacts: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                setState(() {
                  _isLoadingContacts = true;
                });
                _loadContacts();
              },
            ),
          ),
        );
      }
    }
  }

  void _toggleMember(String memberId) {
    setState(() {
      if (_selectedMembers.contains(memberId)) {
        _selectedMembers.remove(memberId);
      } else {
        _selectedMembers.add(memberId);
      }
    });
  }

  Future<void> _addMembers() async {
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Add each selected member to the group
      for (String memberId in _selectedMembers) {
        await _groupRepository.addMemberToGroup(
          groupId: widget.group.id,
          memberId: memberId,
          addedBy: _currentUserId,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedMembers.length} member${_selectedMembers.length == 1 ? '' : 's'} added successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add members: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color:
              Theme.of(
                context,
              ).scaffoldBackgroundColor, // Change the back button color to white
        ),
        title: const Text(
          'Add Members',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed:
                (_isLoading || _selectedMembers.isEmpty) ? null : _addMembers,
            child: Text(
              'Add',
              style: TextStyle(
                color:
                    (_isLoading || _selectedMembers.isEmpty)
                        ? Colors.grey
                        : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (_selectedMembers.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Text(
                        '${_selectedMembers.length} member${_selectedMembers.length == 1 ? '' : 's'} selected',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Expanded(
                    child:
                        _isLoadingContacts
                            ? const Center(child: CircularProgressIndicator())
                            : _contacts.isEmpty
                            ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No contacts available',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'All your contacts are already in this group or you don\'t have any registered contacts.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : ListView.builder(
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                final contact = _contacts[index];
                                final isSelected = _selectedMembers.contains(
                                  contact['id'],
                                );

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).primaryColor,
                                      child: Text(
                                        contact['name'][0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      contact['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(contact['phoneNumber']),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      onChanged:
                                          (_) => _toggleMember(contact['id']),
                                      activeColor:
                                          Theme.of(context).primaryColor,
                                    ),
                                    onTap: () => _toggleMember(contact['id']),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
