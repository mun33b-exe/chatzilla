import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/group_model.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Theme.of(context).primaryColorDark,
        backgroundImage:
            group.imageUrl != null ? NetworkImage(group.imageUrl!) : null,
        child:
            group.imageUrl == null
                ? Text(
                  group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                )
                : null,
      ),
      title: Row(
        children: [
          // Group icon indicator
          Icon(Icons.group, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.lastMessage != null) ...[
            Row(
              children: [
                // Show sender name for last message if it's not from current user
                if (group.lastMessageSenderId != currentUserId &&
                    group.participantsName[group.lastMessageSenderId!] != null)
                  Text(
                    '${group.participantsName[group.lastMessageSenderId!]}: ',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  )
                else if (group.lastMessageSenderId == currentUserId)
                  Text(
                    'You: ',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                Expanded(
                  child: Text(
                    group.lastMessage!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          Text(
            '${group.participants.length} participants',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (group.lastMessageTime != null)
            Text(
              _formatTime(group.lastMessageTime!.toDate()),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Unread count for groups
              StreamBuilder<int>(
                stream: getIt<ChatRepository>().getGroupUnreadCount(
                  group.id,
                  currentUserId,
                ),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  if (unreadCount > 0) {
                    return Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox(width: 4);
                },
              ),
              // Group indicator badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'GROUP',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('h:mm a').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('M/d/yy').format(time);
    }
  }
}
