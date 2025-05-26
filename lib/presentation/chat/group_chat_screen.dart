import 'dart:io';
import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../data/models/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/services/service_locator.dart';
import '../../logic/cubit/chat/chat_cubit.dart';
import '../../logic/cubit/chat/chat_state.dart';
import '../../logic/cubit/group/group_cubit.dart';
import '../../logic/cubit/group/group_state.dart';
import '../widgets/reply_message_widget.dart';
import '../screens/group/group_info_screen.dart';
import '../../router/app_router.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController messageController = TextEditingController();
  late final ChatCubit _chatCubit;
  late final GroupCubit _groupCubit;
  final _scrollController = ScrollController();

  List<ChatMessage> _previousMessages = [];
  bool _isComposing = false;
  bool _showEmoji = false;
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};

  @override
  void initState() {
    super.initState();

    // Get current user ID from auth repository
    final currentUserId = getIt<AuthRepository>().currentUser?.uid ?? '';

    // Create cubit instances with proper user ID
    _chatCubit = getIt.get<ChatCubit>(param1: currentUserId);
    _groupCubit = getIt.get<GroupCubit>(param1: currentUserId);

    // Load group details
    _groupCubit.getGroupById(widget.groupId);

    messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();

    // Dispose animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  void _onTextChanged() {
    final isComposing = messageController.text.isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });

      // Update typing status for group
      if (isComposing) {
        _startGroupTyping();
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreGroupMessages();
    }
  }

  void _startGroupTyping() {
    // Implement group typing logic here
    // Similar to individual chat but for groups
  }

  void _loadMoreGroupMessages() {
    // Implement pagination for group messages
    // Similar to individual chat
  }

  Future<void> _handleSendMessage() async {
    final messageText = messageController.text.trim();
    if (messageText.isEmpty) return;

    messageController.clear();
    setState(() {
      _isComposing = false;
    });

    try {
      final currentState = _chatCubit.state;
      final replyToMessage = currentState.replyingToMessage;

      // Get current user name from group participants
      String? senderName;
      final groupState = _groupCubit.state;
      if (groupState.selectedGroup != null) {
        senderName =
            groupState.selectedGroup!.participantsName[_chatCubit
                .currentUserId] ??
            'Unknown';
      }

      await getIt<ChatRepository>().sendGroupMessage(
        groupId: widget.groupId,
        senderId: _chatCubit.currentUserId,
        content: messageText,
        senderName: senderName ?? 'Unknown',
        replyToMessageId: replyToMessage?.id,
        replyToContent: replyToMessage?.content,
        replyToSenderId: replyToMessage?.senderId,
        replyToSenderName: replyToMessage?.senderName,
      );

      // Clear reply after sending
      if (replyToMessage != null) {
        _chatCubit.clearReply();
      }

      _scrollToBottom();
    } catch (e) {
      print('Error sending group message: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildGroupAppBar() {
    return BlocBuilder<GroupCubit, GroupState>(
      bloc: _groupCubit,
      builder: (context, state) {
        if (state.selectedGroup == null) {
          return AppBar(
            title: Text(widget.groupName),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          );
        }

        final group = state.selectedGroup!;

        return AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          title: InkWell(
            onTap: () {
              getIt<AppRouter>().push(GroupInfoScreen(groupId: widget.groupId));
            },
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColorDark,
                  backgroundImage:
                      group.imageUrl != null
                          ? NetworkImage(group.imageUrl!)
                          : null,
                  child:
                      group.imageUrl == null
                          ? Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(color: Colors.white),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${group.participants.length} participants',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'info':
                    getIt<AppRouter>().push(
                      GroupInfoScreen(groupId: widget.groupId),
                    );
                    break;
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'info',
                      child: Text('Group Info'),
                    ),
                  ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildGroupAppBar(),
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: getIt<ChatRepository>().getGroupMessages(widget.groupId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return Container(
                  color: const Color(0xFFECF2F4),
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == _chatCubit.currentUserId;

                      return _buildGroupMessageBubble(message, isMe);
                    },
                  ),
                );
              },
            ),
          ),

          // Input area
          Container(
            color: Theme.of(context).primaryColor,
            padding: const EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: 16,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview
                  BlocBuilder<ChatCubit, ChatState>(
                    bloc: _chatCubit,
                    builder: (context, state) {
                      if (state.replyingToMessage == null) {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ReplyMessageWidget(
                          replyToMessage: state.replyingToMessage,
                          currentUserId: _chatCubit.currentUserId,
                          isPreview: true,
                          onCancel: () => _chatCubit.clearReply(),
                          senderName: state.replyingToMessage?.senderName,
                        ),
                      );
                    },
                  ),

                  // Message input row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: TextField(
                            controller: messageController,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: "Type a message",
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              fillColor: Theme.of(context).cardColor,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showEmoji = !_showEmoji;
                                    if (_showEmoji) {
                                      FocusScope.of(context).unfocus();
                                    }
                                  });
                                },
                                icon: const Icon(Icons.emoji_emotions),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isComposing ? _handleSendMessage : null,
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColorDark,
                          radius: 22,
                          child: Icon(
                            Icons.send,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Emoji picker
                  if (_showEmoji)
                    SizedBox(
                      height: 250,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          messageController
                            ..text += emoji.emoji
                            ..selection = TextSelection.fromPosition(
                              TextPosition(
                                offset: messageController.text.length,
                              ),
                            );
                          setState(() {
                            _isComposing = messageController.text.isNotEmpty;
                          });
                        },
                        config: Config(
                          height: 250,
                          emojiViewConfig: EmojiViewConfig(
                            columns: 7,
                            emojiSizeMax: 32.0 * (Platform.isIOS ? 1.30 : 1.0),
                            verticalSpacing: 0,
                            horizontalSpacing: 0,
                            gridPadding: EdgeInsets.zero,
                            backgroundColor:
                                Theme.of(context).scaffoldBackgroundColor,
                            loadingIndicator: const SizedBox.shrink(),
                          ),
                          categoryViewConfig: const CategoryViewConfig(
                            initCategory: Category.RECENT,
                          ),
                          bottomActionBarConfig: BottomActionBarConfig(
                            enabled: true,
                            backgroundColor:
                                Theme.of(context).scaffoldBackgroundColor,
                            buttonColor: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupMessageBubble(ChatMessage message, bool isMe) {
    return GestureDetector(
      onLongPress: () => _chatCubit.setReplyToMessage(message),
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 64 : 8,
          right: isMe ? 8 : 64,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Show sender name for group messages (except for own messages)
            if (!isMe && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  message.senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),

            // Reply preview if this message is a reply
            if (message.replyToMessageId != null) ...[
              ReplyMessageWidget(
                replyToMessage: ChatMessage(
                  id: message.replyToMessageId!,
                  chatRoomId: message.chatRoomId,
                  senderId: message.replyToSenderId!,
                  content: message.replyToContent!,
                  timestamp: message.timestamp,
                  status: MessageStatus.sent,
                  readBy: [],
                  chatType: ChatType.group,
                  senderName: message.replyToSenderName,
                ),
                currentUserId: _chatCubit.currentUserId,
                isPreview: false,
                senderName: message.replyToSenderName,
              ),
              const SizedBox(height: 4),
            ],

            // Message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm a').format(message.timestamp.toDate()),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color:
                              message.status == MessageStatus.read
                                  ? Theme.of(context).primaryColorDark
                                  : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
