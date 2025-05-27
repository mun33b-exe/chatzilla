import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/common/custom_button.dart';
import '../../../core/common/custom_text_field.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/services/service_locator.dart';
import '../../../logic/cubit/group/group_cubit.dart';
import '../../../logic/cubit/group/group_state.dart';
import '../../../router/app_router.dart';
import '../../chat/group_chat_screen.dart';
import '../../../data/repositories/auth_repository.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ContactRepository _contactRepository = getIt<ContactRepository>();

  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _selectedContacts = [];
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      // Use the optimized contact fetching with caching
      final contacts = await _contactRepository.getRegisteredContacts();
      if (mounted) {
        setState(() {
          _allContacts = contacts;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
        UiUtils.showSnackBar(context, message: 'Failed to load contacts: $e');
      }
    }
  }

  void _toggleContactSelection(Map<String, dynamic> contact) {
    setState(() {
      if (_selectedContacts.any((c) => c['id'] == contact['id'])) {
        _selectedContacts.removeWhere((c) => c['id'] == contact['id']);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  String? _validateGroupName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a group name';
    }
    if (value.trim().length < 3) {
      return 'Group name must be at least 3 characters';
    }
    return null;
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedContacts.isEmpty) {
      UiUtils.showSnackBar(
        context,
        message: 'Please select at least one contact',
      );
      return;
    }

    try {
      // Get current user ID from auth repository
      final currentUserId = getIt<AuthRepository>().currentUser?.uid ?? '';

      if (currentUserId.isEmpty) {
        UiUtils.showSnackBar(context, message: 'User not authenticated');
        return;
      }

      // Get current user's actual name from database
      final currentUserData = await getIt<AuthRepository>().getUserData(
        currentUserId,
      );
      final currentUserName = currentUserData.fullName;

      if (currentUserName.isEmpty) {
        UiUtils.showSnackBar(
          context,
          message: 'Unable to get current user name',
        );
        return;
      }

      final groupCubit = getIt.get<GroupCubit>(param1: currentUserId);

      // Prepare participants list (include current user)
      final participants = [
        currentUserId,
        ..._selectedContacts.map((c) => c['id'] as String),
      ];

      // Prepare participants name map with actual current user name
      final participantsName = <String, String>{currentUserId: currentUserName};

      for (final contact in _selectedContacts) {
        participantsName[contact['id']] = contact['name'];
      }

      await groupCubit.createGroup(
        name: _groupNameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        participants: participants,
        participantsName: participantsName,
      );
    } catch (e) {
      UiUtils.showSnackBar(context, message: 'Error preparing group data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current user ID from auth repository
    final currentUserId = getIt<AuthRepository>().currentUser?.uid ?? '';

    return BlocProvider(
      create: (context) => getIt.get<GroupCubit>(param1: currentUserId),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Group'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<GroupCubit, GroupState>(
          listener: (context, state) {
            if (state.status == GroupStatus.error && state.error != null) {
              UiUtils.showSnackBar(context, message: state.error!);
            }

            if (state.createdGroupId != null) {
              UiUtils.showSnackBar(
                context,
                message: 'Group created successfully!',
              );
              // Navigate to the group chat
              getIt<AppRouter>().pushReplacement(
                GroupChatScreen(
                  groupId: state.createdGroupId!,
                  groupName: _groupNameController.text.trim(),
                ),
              );
            }
          },
          builder: (context, state) {
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  // Group details section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[100],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Group Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _groupNameController,
                          hintText: 'Group Name',
                          validator: _validateGroupName,
                          prefixIcon: const Icon(Icons.group),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _descriptionController,
                          hintText: 'Group Description (Optional)',
                          prefixIcon: const Icon(Icons.description),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                  // Selected contacts section
                  if (_selectedContacts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected (${_selectedContacts.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _selectedContacts[index];
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    avatar: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).primaryColorDark,
                                      child: Text(
                                        contact['name'][0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    label: Text(contact['name']),
                                    onDeleted:
                                        () => _toggleContactSelection(contact),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Contacts list
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Select Contacts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: _buildContactsList()),
                      ],
                    ),
                  ),

                  // Create button
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: CustomButton(
                      onPressed: state.isCreating ? null : _createGroup,
                      text: 'Create Group',
                      child:
                          state.isCreating
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                'Create Group',
                                style: TextStyle(color: Colors.white),
                              ),
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

  Widget _buildContactsList() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allContacts.isEmpty) {
      return const Center(child: Text('No contacts found'));
    }

    return ListView.builder(
      itemCount: _allContacts.length,
      itemBuilder: (context, index) {
        final contact = _allContacts[index];
        final isSelected = _selectedContacts.any(
          (c) => c['id'] == contact['id'],
        );

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColorDark,
            foregroundImage: NetworkImage(
              "https://ui-avatars.com/api/?name=${Uri.encodeComponent(contact['name'])}&background=${Theme.of(context).primaryColorDark.value.toRadixString(16).substring(2)}&color=fff",
            ),
            child: Text(
              contact['name'][0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(contact['name']),
          subtitle: Text(contact['phoneNumber']),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (value) => _toggleContactSelection(contact),
            activeColor: Theme.of(context).primaryColor,
          ),
          onTap: () => _toggleContactSelection(contact),
        );
      },
    );
  }
}
