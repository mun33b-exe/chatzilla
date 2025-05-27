import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/contact_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/group/groups_cubit.dart';
import 'package:chatzilla/logic/cubit/group/groups_state.dart';
import 'package:chatzilla/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ContactRepository _contactRepository = getIt<ContactRepository>();
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
      // Add timeout to prevent indefinite loading
      final contacts = await _contactRepository.getRegisteredContacts().timeout(
        const Duration(seconds: 10),
      );
      if (mounted) {
        setState(() {
          _contacts = contacts;
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
    if (mounted) {
      setState(() {
        if (_selectedMembers.contains(memberId)) {
          _selectedMembers.remove(memberId);
        } else {
          _selectedMembers.add(memberId);
        }
      });
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
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
      // Ensure current user is included in the group
      final allMembers = Set<String>.from(_selectedMembers);
      allMembers.add(_currentUserId);

      await getIt<GroupsCubit>().createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        members: allMembers.toList(),
      );

      if (mounted) {
        getIt<AppRouter>().pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
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
        title: const Text('Create Group'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: (_isLoading || _isLoadingContacts) ? null : _createGroup,
            child: Text(
              'Create',
              style: TextStyle(
                color:
                    (_isLoading || _isLoadingContacts)
                        ? Colors.grey
                        : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<GroupsCubit, GroupsState>(
        bloc: getIt<GroupsCubit>(),
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Image Placeholder
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              // TODO: Implement image picker
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Image picker not implemented yet',
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Group Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Group Name',
                            hintText: 'Enter group name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.group),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a group name';
                            }
                            if (value.trim().length < 3) {
                              return 'Group name must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Group Description
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            hintText: 'Enter group description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.description),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Members Section
                        Text(
                          'Add Members',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select contacts to add to the group',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Selected Members Count
                        if (_selectedMembers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_selectedMembers.length} member${_selectedMembers.length == 1 ? '' : 's'} selected',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16), // Contacts List
                        if (_isLoadingContacts)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_contacts.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'No contacts found.\nMake sure you have contacts with registered phone numbers.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _contacts.length,
                            itemBuilder: (context, index) {
                              final contact = _contacts[index];
                              final isSelected = _selectedMembers.contains(
                                contact['id'],
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
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
                                    activeColor: Theme.of(context).primaryColor,
                                  ),
                                  onTap: () => _toggleMember(contact['id']),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
