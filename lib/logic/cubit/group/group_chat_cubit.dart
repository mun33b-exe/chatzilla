import 'dart:async';
import 'dart:developer';

import 'package:chatzilla/data/models/chat_message.dart';
import 'package:chatzilla/data/repositories/group_repository.dart';
import 'package:chatzilla/logic/cubit/group/group_chat_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GroupChatCubit extends Cubit<GroupChatState> {
  final GroupRepository _groupRepository;
  final String currentUserId;
  final String currentUserName;
  bool _isInGroup = false;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  Timer? typingTimer;

  GroupChatCubit({
    required GroupRepository groupRepository,
    required this.currentUserId,
    required this.currentUserName,
  }) : _groupRepository = groupRepository,
       super(const GroupChatState());

  void enterGroup(String groupId) async {
    _isInGroup = true;
    emit(state.copyWith(status: GroupChatStatus.loading));

    try {
      final group = await _groupRepository.getGroup(groupId);
      if (group == null) {
        emit(
          state.copyWith(
            status: GroupChatStatus.error,
            error: "Group not found",
          ),
        );
        return;
      }

      if (!group.isMember(currentUserId)) {
        emit(
          state.copyWith(
            status: GroupChatStatus.error,
            error: "You are not a member of this group",
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          groupId: groupId,
          group: group,
          status: GroupChatStatus.loaded,
        ),
      );

      // Subscribe to updates
      _subscribeToMessages(groupId);
      _subscribeToTypingStatus(groupId);
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupChatStatus.error,
          error: "Failed to load group: $e",
        ),
      );
    }
  }

  Future<void> sendMessage({
    required String content,
    ChatMessage? replyToMessage,
    String? replyToSenderName,
  }) async {
    if (state.groupId == null || state.group == null) return;

    final group = state.group!;

    // Check if user can send messages
    if (group.settings.onlyAdminsCanMessage && !group.isAdmin(currentUserId)) {
      emit(
        state.copyWith(error: "Only admins can send messages in this group"),
      );
      return;
    }

    try {
      await _groupRepository.sendGroupMessage(
        groupId: state.groupId!,
        senderId: currentUserId,
        content: content,
        senderName: currentUserName,
        replyToMessageId: replyToMessage?.id,
        replyToContent: replyToMessage?.content,
        replyToSenderId: replyToMessage?.senderId,
        replyToSenderName: replyToSenderName,
      );

      // Clear reply after sending
      if (state.replyingToMessage != null) {
        emit(state.copyWith(clearReply: true));
      }
    } catch (e) {
      log(e.toString());
      emit(state.copyWith(error: "Failed to send message"));
    }
  }

  void setReplyToMessage(ChatMessage? message) {
    emit(state.copyWith(replyingToMessage: message));
  }

  void clearReply() {
    emit(state.copyWith(clearReply: true));
  }

  Future<void> loadMoreMessages() async {
    if (state.status != GroupChatStatus.loaded ||
        state.messages.isEmpty ||
        !state.hasMoreMessages ||
        state.isLoadingMore)
      return;

    try {
      emit(state.copyWith(isLoadingMore: true));

      final lastMessage = state.messages.last;
      final lastDoc =
          await _groupRepository
              .getGroupMessages(state.groupId!)
              .doc(lastMessage.id)
              .get();

      final moreMessages = await _groupRepository.getMoreGroupMessages(
        state.groupId!,
        lastDocument: lastDoc,
      );

      if (moreMessages.isEmpty) {
        emit(state.copyWith(hasMoreMessages: false, isLoadingMore: false));
        return;
      }

      emit(
        state.copyWith(
          messages: [...state.messages, ...moreMessages],
          hasMoreMessages: moreMessages.length >= 20,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: "Failed to load more messages",
          isLoadingMore: false,
        ),
      );
    }
  }

  void _subscribeToMessages(String groupId) {
    _messageSubscription?.cancel();
    _messageSubscription = _groupRepository
        .getGroupMessagesStream(groupId)
        .listen(
          (messages) {
            if (_isInGroup) {
              _markMessagesAsRead(groupId);
            }
            emit(state.copyWith(messages: messages, error: null));
          },
          onError: (error) {
            emit(
              state.copyWith(
                error: "Failed to load messages",
                status: GroupChatStatus.error,
              ),
            );
          },
        );
  }

  void _subscribeToTypingStatus(String groupId) {
    _typingSubscription?.cancel();
    _typingSubscription = _groupRepository
        .getGroupTypingStatus(groupId)
        .listen(
          (status) {
            final isTyping = status["isTyping"] as bool;
            final typingUserId = status["typingUserId"] as String?;

            emit(
              state.copyWith(
                isTyping: isTyping && typingUserId != currentUserId,
                typingUserId: typingUserId,
              ),
            );
          },
          onError: (error) {
            print("Error getting typing status: $error");
          },
        );
  }

  void startTyping() {
    if (state.groupId == null) return;

    _groupRepository.updateGroupTypingStatus(
      state.groupId!,
      currentUserId,
      true,
    );

    // Auto-stop typing after 3 seconds
    typingTimer?.cancel();
    typingTimer = Timer(const Duration(seconds: 3), () {
      stopTyping();
    });
  }

  void stopTyping() {
    if (state.groupId == null) return;

    typingTimer?.cancel();
    _groupRepository.updateGroupTypingStatus(
      state.groupId!,
      currentUserId,
      false,
    );
  }

  Future<void> addMember(String memberId) async {
    if (state.groupId == null || state.group == null) return;

    final group = state.group!;

    // Check permissions
    if (group.settings.onlyAdminsCanAddMembers &&
        !group.isAdmin(currentUserId)) {
      emit(state.copyWith(error: "Only admins can add members"));
      return;
    }

    try {
      await _groupRepository.addMemberToGroup(
        groupId: state.groupId!,
        memberId: memberId,
        addedBy: currentUserId,
      );
    } catch (e) {
      emit(state.copyWith(error: "Failed to add member"));
    }
  }

  Future<void> removeMember(String memberId) async {
    if (state.groupId == null || state.group == null) return;

    final group = state.group!;

    // Check permissions (only admins can remove, and creator can remove anyone)
    if (!group.isAdmin(currentUserId)) {
      emit(state.copyWith(error: "Only admins can remove members"));
      return;
    }

    try {
      await _groupRepository.removeMemberFromGroup(
        groupId: state.groupId!,
        memberId: memberId,
        removedBy: currentUserId,
      );
    } catch (e) {
      emit(state.copyWith(error: "Failed to remove member"));
    }
  }

  Future<void> leaveGroup() async {
    if (state.groupId == null) return;

    try {
      await _groupRepository.leaveGroup(
        groupId: state.groupId!,
        userId: currentUserId,
      );
    } catch (e) {
      emit(state.copyWith(error: "Failed to leave group"));
    }
  }

  Future<void> makeAdmin(String memberId) async {
    if (state.groupId == null || state.group == null) return;

    final group = state.group!;

    // Only existing admins or creator can make someone admin
    if (!group.isAdmin(currentUserId)) {
      emit(state.copyWith(error: "Only admins can promote members"));
      return;
    }

    try {
      await _groupRepository.makeAdmin(
        groupId: state.groupId!,
        memberId: memberId,
        promotedBy: currentUserId,
      );
    } catch (e) {
      emit(state.copyWith(error: "Failed to make admin"));
    }
  }

  Future<void> removeAdmin(String memberId) async {
    if (state.groupId == null || state.group == null) return;

    final group = state.group!;

    // Only creator can remove admin privileges
    if (!group.isCreator(currentUserId)) {
      emit(
        state.copyWith(error: "Only group creator can remove admin privileges"),
      );
      return;
    }

    try {
      await _groupRepository.removeAdmin(
        groupId: state.groupId!,
        memberId: memberId,
        removedBy: currentUserId,
      );
    } catch (e) {
      emit(state.copyWith(error: "Failed to remove admin"));
    }
  }

  Future<void> _markMessagesAsRead(String groupId) async {
    try {
      await _groupRepository.markGroupMessagesAsRead(groupId, currentUserId);
    } catch (e) {
      print("Error marking group messages as read: $e");
    }
  }

  Future<void> leaveChat() async {
    _isInGroup = false;
    stopTyping();
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    typingTimer?.cancel();
    return super.close();
  }
}
