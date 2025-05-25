import 'package:chatzilla/data/models/chat_message.dart';
import 'package:flutter/material.dart';

class ReplyMessageWidget extends StatelessWidget {
  final ChatMessage? replyToMessage;
  final String currentUserId;
  final VoidCallback? onCancel;
  final bool isPreview; // If true, shows in input area. If false, shows in message bubble.
  final String? senderName; // Optional sender name to display instead of "Other"

  const ReplyMessageWidget({
    super.key,
    required this.replyToMessage,
    required this.currentUserId,
    this.onCancel,
    this.isPreview = false,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    if (replyToMessage == null) return const SizedBox.shrink();    final message = replyToMessage!;
    final isMe = message.senderId == currentUserId;
    final displayName = isMe ? "You" : (senderName ?? "Unknown User");

    return Container(
      margin: isPreview 
          ? const EdgeInsets.only(left: 8, right: 8, bottom: 8)
          : const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isPreview 
            ? Theme.of(context).cardColor
            : (isMe 
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: isPreview 
                        ? Theme.of(context).textTheme.bodyMedium?.color
                        : (isMe ? Colors.white70 : Colors.grey[700]),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isPreview && onCancel != null)
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 18),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
