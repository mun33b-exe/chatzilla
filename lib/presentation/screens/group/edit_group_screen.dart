import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/common/custom_button.dart';
import '../../../core/common/custom_text_field.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/group_model.dart';
import '../../../data/services/service_locator.dart';
import '../../../logic/cubit/group/group_cubit.dart';
import '../../../logic/cubit/group/group_state.dart';

class EditGroupScreen extends StatefulWidget {
  final GroupModel group;

  const EditGroupScreen({super.key, required this.group});

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _groupNameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(
      text: widget.group.description ?? '',
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final groupCubit = getIt<GroupCubit>();

    // Check if any changes were made
    final newName = _groupNameController.text.trim();
    final newDescription =
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim();

    if (newName == widget.group.name &&
        newDescription == widget.group.description) {
      UiUtils.showSnackBar(context, message: 'No changes to save');
      return;
    }

    await groupCubit.updateGroupInfo(
      groupId: widget.group.id,
      name: newName != widget.group.name ? newName : null,
      description:
          newDescription != widget.group.description ? newDescription : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<GroupCubit>(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Group'),
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
                message: 'Group updated successfully!',
              );
              Navigator.pop(context);
            }
          },
          builder: (context, state) {
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group image section
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor:
                                      Theme.of(context).primaryColorDark,
                                  backgroundImage:
                                      widget.group.imageUrl != null
                                          ? NetworkImage(widget.group.imageUrl!)
                                          : null,
                                  child:
                                      widget.group.imageUrl == null
                                          ? Text(
                                            widget.group.name.isNotEmpty
                                                ? widget.group.name[0]
                                                    .toUpperCase()
                                                : 'G',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                          : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        // TODO: Implement image picker
                                        UiUtils.showSnackBar(
                                          context,
                                          message: 'Image picker coming soon!',
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Group details section
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
                          ),
                          const SizedBox(height: 16),

                          CustomTextField(
                            controller: _descriptionController,
                            hintText: 'Group Description (Optional)',
                            prefixIcon: const Icon(Icons.description),
                            maxLines: 3,
                          ),

                          const SizedBox(height: 24),

                          // Group stats
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          '${widget.group.participants.length}',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                        const Text(
                                          'Participants',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          '${widget.group.admins.length}',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                        const Text(
                                          'Admins',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Created ${_formatDate(widget.group.createdAt.toDate())}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Save button
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: CustomButton(
                      onPressed: state.isUpdating ? null : _updateGroup,
                      text: 'Save Changes',
                      child:
                          state.isUpdating
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                'Save Changes',
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
}
