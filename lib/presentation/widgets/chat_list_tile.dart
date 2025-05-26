import 'package:chatzilla/data/models/chat_room_model.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatListTile extends StatelessWidget {
  final ChatRoomModel chat;
  final String currentUserId;
  final VoidCallback onTap;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUserId = chat.participants.firstWhere(
      (id) => id != currentUserId,
    );

    final otherUserName = chat.participantsName?[otherUserId] ?? "Unknown";

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Theme.of(context).primaryColorDark,
        foregroundImage: NetworkImage(
          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(otherUserName)}&background=${Theme.of(context).primaryColorDark.value.toRadixString(16).substring(2)}&color=fff",
        ),
        child: Text(
          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : "?",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          // Person icon indicator for individual chats
          Icon(Icons.person, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              otherUserName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle:
          chat.lastMessage != null
              ? Row(
                children: [
                  if (chat.lastMessageSenderId == currentUserId)
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
                      chat.lastMessage!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
              : Text(
                'No messages yet',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (chat.lastMessageTime != null)
            Text(
              _formatTime(chat.lastMessageTime!.toDate()),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          const SizedBox(height: 4),
          // Unread count indicator
          StreamBuilder<int>(
            stream: getIt<ChatRepository>().getUnreadCount(
              chat.id,
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
              return const SizedBox.shrink();
            },
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
