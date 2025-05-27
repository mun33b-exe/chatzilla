import 'package:chatzilla/data/models/group_model.dart';
import 'package:flutter/material.dart';

class GroupInfoScreen extends StatelessWidget {
  final GroupModel group;

  const GroupInfoScreen({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Group Info Screen\n(Coming Soon)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
