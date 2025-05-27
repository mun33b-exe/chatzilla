import 'package:chatzilla/data/models/group_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GroupListTile extends StatelessWidget {
  final GroupModel group;
  final String currentUserId;
  final VoidCallback onTap;

  const GroupListTile({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.onTap,
  });
  String _getLastMessageTime() {
    if (group.lastMessageTime == null) return '';

    final now = DateTime.now();
    final messageTime = group.lastMessageTime!.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return DateFormat('MMM dd').format(messageTime);
    } else {
      return DateFormat('h:mm a').format(messageTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasUnreadMessages = group.hasUnreadMessages(currentUserId);
    final int memberCount = group.members.length;

    return Column(
      children: [
        ListTile(
          tileColor:
              hasUnreadMessages
                  ? const Color(
                    0xFFE3F2FD,
                  ) // Light bluish tone for unread messages
                  : const Color(0xFFECF2F4), // Original color for read messages
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 16,
          ),
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColorDark,
            backgroundImage:
                group.groupImageUrl != null
                    ? NetworkImage(group.groupImageUrl!)
                    : null,
            child:
                group.groupImageUrl == null
                    ? Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                      style: TextStyle(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        fontSize: 20,
                      ),
                    )
                    : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: TextStyle(
                    fontWeight:
                        hasUnreadMessages ? FontWeight.bold : FontWeight.w500,
                    fontSize: 16,
                    color:
                        hasUnreadMessages
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).textTheme.titleMedium?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.group, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '$memberCount',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                group.lastMessage ?? 'No messages yet',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      hasUnreadMessages
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                  fontWeight:
                      hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (group.lastMessageTime != null)
                Text(
                  _getLastMessageTime(),
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        hasUnreadMessages
                            ? Theme.of(context).primaryColor
                            : Colors.grey[600],
                    fontWeight:
                        hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              const SizedBox(height: 4),
              if (hasUnreadMessages)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '•',
                    style: const TextStyle(color: Colors.white, fontSize: 8),
                  ),
                ),
            ],
          ),
        ),
        const Divider(
          height: 0,
          thickness: 2,
          indent: 20,
          endIndent: 20,
          color: Color(0xFFE0E0E0),
        ),
      ],
    );
  }
}
