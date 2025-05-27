import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/common/custom_button.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/contact_repository.dart';
import '../../../data/services/service_locator.dart';
import '../../../logic/cubit/group/group_cubit.dart';
import '../../../logic/cubit/group/group_state.dart';

class AddParticipantsScreen extends StatefulWidget {
  final String groupId;
  final List<String> existingParticipants;

  const AddParticipantsScreen({
    super.key,
    required this.groupId,
    required this.existingParticipants,
  });

  @override
  State<AddParticipantsScreen> createState() => _AddParticipantsScreenState();
}

class _AddParticipantsScreenState extends State<AddParticipantsScreen> {
  final ContactRepository _contactRepository = getIt<ContactRepository>();

  List<Map<String, dynamic>> _availableContacts = [];
  List<Map<String, dynamic>> _selectedContacts = [];
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableContacts();
  }

  Future<void> _loadAvailableContacts() async {
    try {
      // Use the optimized contact fetching with caching
      final allContacts = await _contactRepository.getRegisteredContacts();

      // Filter out contacts that are already in the group
      final availableContacts =
          allContacts
              .where(
                (contact) =>
                    !widget.existingParticipants.contains(contact['id']),
              )
              .toList();

      if (mounted) {
        setState(() {
          _availableContacts = availableContacts;
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

  Future<void> _addParticipants() async {
    if (_selectedContacts.isEmpty) {
      UiUtils.showSnackBar(
        context,
        message: 'Please select at least one contact',
      );
      return;
    }

    // Get current user ID from auth repository
    final currentUserId = getIt<AuthRepository>().currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      UiUtils.showSnackBar(context, message: 'User not authenticated');
      return;
    }

    // Get a fresh instance of GroupCubit with the current user ID
    final groupCubit = getIt.get<GroupCubit>(param1: currentUserId);

    // Prepare new participants list
    final newParticipants =
        _selectedContacts.map((c) => c['id'] as String).toList();

    // Prepare new participants name map
    final newParticipantsName = <String, String>{};
    for (final contact in _selectedContacts) {
      newParticipantsName[contact['id']] = contact['name'];
    }

    await groupCubit.addParticipants(
      groupId: widget.groupId,
      newParticipants: newParticipants,
      newParticipantsName: newParticipantsName,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current user ID from auth repository
    final currentUserId = getIt<AuthRepository>().currentUser?.uid ?? '';

    return BlocProvider(
      create: (context) => getIt.get<GroupCubit>(param1: currentUserId),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Participants'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<GroupCubit, GroupState>(
          listener: (context, state) {
            if (state.status == GroupStatus.error && state.error != null) {
              UiUtils.showSnackBar(context, message: state.error!);
            }

            if (state.isUpdating == false &&
                state.status == GroupStatus.loaded) {
              UiUtils.showSnackBar(
                context,
                message: 'Participants added successfully!',
              );
              Navigator.pop(context);
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                // Selected participants section
                if (_selectedContacts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey[50],
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
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Available contacts list
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Available Contacts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: _buildAvailableContactsList()),
                    ],
                  ),
                ), // Add button
                Container(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    onPressed: state.isUpdating ? null : _addParticipants,
                    text: 'Add Participants',
                    child:
                        state.isUpdating
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Add Participants',
                              style: TextStyle(color: Colors.white),
                            ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvailableContactsList() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableContacts.isEmpty) {
      return const Center(child: Text('No available contacts to add'));
    }

    return ListView.builder(
      itemCount: _availableContacts.length,
      itemBuilder: (context, index) {
        final contact = _availableContacts[index];
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
