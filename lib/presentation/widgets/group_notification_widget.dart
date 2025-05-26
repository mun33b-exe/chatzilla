import 'package:flutter/material.dart';

class GroupNotificationWidget extends StatelessWidget {
  final String groupName;
  final String senderName;
  final String message;
  final VoidCallback onTap;

  const GroupNotificationWidget({
    super.key,
    required this.groupName,
    required this.senderName,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(
            Icons.group,
            color: Colors.white,
          ),
        ),
        title: Text(
          groupName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey[600]),
            children: [
              TextSpan(
                text: '$senderName: ',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              TextSpan(text: message),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}