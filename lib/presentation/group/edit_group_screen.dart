// filepath: f:\chatzilla\lib\presentation\group\edit_group_screen.dart
import 'package:chatzilla/data/models/group_model.dart';
import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/group_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:flutter/material.dart';

class EditGroupScreen extends StatefulWidget {
  final GroupModel group;

  const EditGroupScreen({super.key, required this.group});

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GroupRepository _groupRepository = getIt<GroupRepository>();
  final String _currentUserId = getIt<AuthRepository>().currentUser?.uid ?? "";

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.group.name;
    _descriptionController.text = widget.group.description;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if there are any changes
    final newName = _nameController.text.trim();
    final newDescription = _descriptionController.text.trim();

    if (newName == widget.group.name &&
        newDescription == widget.group.description) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _groupRepository.updateGroupInfo(
        groupId: widget.group.id,
        name: newName != widget.group.name ? newName : null,
        description:
            newDescription != widget.group.description ? newDescription : null,
      );

      if (mounted) {
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate changes were made
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update group: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check permissions
    final canEdit =
        widget.group.isAdmin(_currentUserId) &&
        (widget.group.settings.onlyAdminsCanEditInfo
            ? widget.group.isAdmin(_currentUserId)
            : true);

    if (!canEdit) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Group'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Permission Denied',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Only admins can edit group information.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color:
              Theme.of(context).appBarTheme.foregroundColor ??
              Theme.of(context).scaffoldBackgroundColor,
        ),

        title: Text(
          'Edit Group',
          style: TextStyle(
            color: Theme.of(context).scaffoldBackgroundColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: Text(
              'Save',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Image (read-only for now)
                      Center(
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
                          child:
                              widget.group.groupImageUrl != null
                                  ? ClipOval(
                                    child: Image.network(
                                      widget.group.groupImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Icon(
                                          Icons.group,
                                          size: 40,
                                          color: Theme.of(context).primaryColor,
                                        );
                                      },
                                    ),
                                  )
                                  : Icon(
                                    Icons.group,
                                    size: 40,
                                    color: Theme.of(context).primaryColor,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Group Name
                      Text(
                        'Group Name',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter group name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.group),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Group name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Group name must be at least 2 characters';
                          }
                          if (value.trim().length > 50) {
                            return 'Group name must be less than 50 characters';
                          }
                          return null;
                        },
                        maxLength: 50,
                      ),
                      const SizedBox(height: 24),

                      // Group Description
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter group description (optional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value != null && value.trim().length > 200) {
                            return 'Description must be less than 200 characters';
                          }
                          return null;
                        },
                        maxLength: 200,
                      ),
                      const SizedBox(height: 24),

                      // Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Only admins can edit group information. Changes will be visible to all group members.',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
