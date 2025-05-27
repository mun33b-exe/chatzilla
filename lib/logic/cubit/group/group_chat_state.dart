import 'package:chatzilla/data/models/chat_message.dart';
import 'package:chatzilla/data/models/group_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum GroupChatStatus { initial, loading, loaded, error }

class GroupChatState extends Equatable {
  final GroupChatStatus status;
  final String? error;
  final String? groupId;
  final GroupModel? group;
  final List<ChatMessage> messages;
  final bool isTyping;
  final String? typingUserId;
  final bool hasMoreMessages;
  final bool isLoadingMore;
  final ChatMessage? replyingToMessage;

  const GroupChatState({
    this.status = GroupChatStatus.initial,
    this.error,
    this.groupId,
    this.group,
    this.messages = const [],
    this.isTyping = false,
    this.typingUserId,
    this.hasMoreMessages = true,
    this.isLoadingMore = false,
    this.replyingToMessage,
  });

  GroupChatState copyWith({
    GroupChatStatus? status,
    String? error,
    String? groupId,
    GroupModel? group,
    List<ChatMessage>? messages,
    bool? isTyping,
    String? typingUserId,
    bool? hasMoreMessages,
    bool? isLoadingMore,
    ChatMessage? replyingToMessage,
    bool clearReply = false,
  }) {
    return GroupChatState(
      status: status ?? this.status,
      error: error ?? this.error,
      groupId: groupId ?? this.groupId,
      group: group ?? this.group,
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      typingUserId: typingUserId ?? this.typingUserId,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      replyingToMessage: clearReply ? null : (replyingToMessage ?? this.replyingToMessage),
    );
  }

  @override
  List<Object?> get props {
    return [
      status,
      error,
      groupId,
      group,
      messages,
      isTyping,
      typingUserId,
      hasMoreMessages,
      isLoadingMore,
      replyingToMessage,
    ];
  }
}
