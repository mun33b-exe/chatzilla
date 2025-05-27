import 'dart:io';

import 'package:chatzilla/data/models/chat_message.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/auth/auth_cubit.dart';
import 'package:chatzilla/logic/cubit/group/group_chat_cubit.dart';
import 'package:chatzilla/logic/cubit/group/group_chat_state.dart';
import 'package:chatzilla/presentation/widgets/reply_message_widget.dart';
import 'package:chatzilla/presentation/group/group_info_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

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
  late final GroupChatCubit _groupChatCubit;
  final _scrollController = ScrollController();
  List<ChatMessage> _previousMessages = [];
  bool _isComposing = false;
  bool _showEmoji = false;
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _initGroupChat();
    messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  void _initGroupChat() async {
    // Get current user data from AuthCubit
    final authCubit = getIt<AuthCubit>();
    final currentUser = authCubit.state.user;
    final currentUserName = currentUser?.fullName ?? "Unknown User";
    _currentUserId = currentUser?.uid ?? "";

    // Create GroupChatCubit with the current user name
    _groupChatCubit = getIt<GroupChatCubit>(param1: currentUserName);
    _groupChatCubit.enterGroup(widget.groupId);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 200) {
      _groupChatCubit.loadMoreMessages();
    }
  }

  void _onTextChanged() {
    final isComposing = messageController.text.isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
      if (isComposing) {
        _groupChatCubit.startTyping();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _hasNewMessages(List<ChatMessage> messages) {
    for (final message in messages) {
      if (!_previousMessages.any((prev) => prev.id == message.id)) {
        _animateNewMessage(message);
        Future.delayed(const Duration(milliseconds: 50), () {
          _scrollToBottom();
        });
      }
    }

    if (messages.length != _previousMessages.length) {
      _previousMessages = messages;
    }
  }

  void _animateNewMessage(ChatMessage message) {
    if (_animationControllers.containsKey(message.id)) {
      return;
    }

    final controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    final animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));

    _animationControllers[message.id] = controller;
    _animations[message.id] = animation;

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _animationControllers.containsKey(message.id)) {
            _animationControllers[message.id]?.dispose();
            _animationControllers.remove(message.id);
            _animations.remove(message.id);
          }
        });
      }
    });

    controller.forward();
  }

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    messageController.dispose();
    _scrollController.dispose();
    _groupChatCubit.leaveChat();
    super.dispose();
  }

  List<Widget> _buildMessageWidgets(List<ChatMessage> messages) {
    if (messages.isEmpty) return [];

    List<Widget> widgets = [];
    String? lastDateString;

    // Reverse messages since they come from Firestore in descending order (newest first)
    // but we want to display them chronologically (oldest first)
    final reversedMessages = messages.reversed.toList();

    for (int i = 0; i < reversedMessages.length; i++) {
      final message = reversedMessages[i];
      final messageDate = message.timestamp.toDate();
      final dateString = DateFormat('MMM dd, yyyy').format(messageDate);

      if (lastDateString != dateString) {
        widgets.add(_buildDateSeparator(dateString));
        lastDateString = dateString;
      }

      widgets.add(_buildMessageBubble(message));
    }

    return widgets;
  }

  Widget _buildDateSeparator(String dateString) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateString,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendMessage() async {
    final messageText = messageController.text.trim();
    if (messageText.isEmpty) return;

    messageController.clear();
    setState(() {
      _isComposing = false;
    });

    final currentState = _groupChatCubit.state;
    final replyToMessage = currentState.replyingToMessage;
    String? replyToSenderName;
    if (replyToMessage != null) {
      if (replyToMessage.senderId == _currentUserId) {
        replyToSenderName = "You";
      } else {
        replyToSenderName = replyToMessage.senderName ?? "Unknown User";
      }
    }

    await _groupChatCubit.sendMessage(
      content: messageText,
      replyToMessage: replyToMessage,
      replyToSenderName: replyToSenderName,
    );

    if (replyToMessage != null) {
      _groupChatCubit.clearReply();
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: BlocBuilder<GroupChatCubit, GroupChatState>(
          bloc: _groupChatCubit,
          builder: (context, state) {
            return GestureDetector(
              onTap: () {
                if (state.group != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => GroupInfoScreen(group: state.group!),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColorDark,
                    foregroundImage:
                        state.group?.groupImageUrl != null
                            ? NetworkImage(state.group!.groupImageUrl!)
                            : null,
                    child: Text(
                      widget.groupName.isNotEmpty
                          ? widget.groupName[0].toUpperCase()
                          : "G",
                      style: TextStyle(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.groupName,
                          style: const TextStyle(
                            color: Color(0xFFF9F7F1),
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        if (state.group != null)
                          Text(
                            "${state.group!.members.length} members",
                            style: const TextStyle(
                              color: Color(0xFFF9F7F1),
                              fontSize: 14,
                            ),
                          ),
                        if (state.isTyping && state.typingUserId != null)
                          Text(
                            "${state.group?.membersName?[state.typingUserId] ?? 'Someone'} is typing...",
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: BlocConsumer<GroupChatCubit, GroupChatState>(
        listener: (context, state) {
          _hasNewMessages(state.messages);
          if (state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        bloc: _groupChatCubit,
        builder: (context, state) {
          if (state.status == GroupChatStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == GroupChatStatus.error) {
            return Center(child: Text(state.error ?? "Something went wrong"));
          }

          return Container(
            color: const Color(0xFFECF2F4),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    reverse: false,
                    physics: const BouncingScrollPhysics(),
                    children: _buildMessageWidgets(state.messages),
                  ),
                ),
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
                        if (state.replyingToMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ReplyMessageWidget(
                              replyToMessage: state.replyingToMessage,
                              currentUserId: _currentUserId,
                              isPreview: true,
                              onCancel: () => _groupChatCubit.clearReply(),
                              senderName:
                                  state.replyingToMessage?.senderId ==
                                          _currentUserId
                                      ? "You"
                                      : state.replyingToMessage?.senderName ??
                                          "Unknown User",
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 120,
                                ),
                                child: TextField(
                                  onTap: () {
                                    if (_showEmoji) {
                                      setState(() {
                                        _showEmoji = false;
                                      });
                                    }
                                  },
                                  controller: messageController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                      color: Theme.of(context).primaryColorDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _isComposing ? _handleSendMessage : null,
                              child: CircleAvatar(
                                backgroundColor:
                                    Theme.of(context).primaryColorDark,
                                radius: 22,
                                child: Icon(
                                  Icons.send,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                                  _isComposing =
                                      messageController.text.isNotEmpty;
                                });
                              },
                              config: Config(
                                height: 250,
                                emojiViewConfig: EmojiViewConfig(
                                  columns: 7,
                                  emojiSizeMax:
                                      32.0 * (Platform.isIOS ? 1.30 : 1.0),
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
                                skinToneConfig: const SkinToneConfig(
                                  enabled: true,
                                  dialogBackgroundColor: Colors.white,
                                  indicatorColor: Colors.grey,
                                ),
                                searchViewConfig: SearchViewConfig(
                                  backgroundColor:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  buttonIconColor:
                                      Theme.of(context).primaryColor,
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
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final currentUserId = _currentUserId;
    final isMe = message.senderId == currentUserId;

    // Handle system messages
    if (message.type == MessageType.systemMessage) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final animation = _animations[message.id];
    Widget messageWidget = Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColorDark,
              radius: 16,
              child: Text(
                (message.senderName?.isNotEmpty == true)
                    ? message.senderName![0].toUpperCase()
                    : "?",
                style: TextStyle(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                _showMessageOptions(context, message);
              },
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.replyToMessageId != null) ...[
                    ReplyMessageWidget(
                      replyToMessage: ChatMessage(
                        id: message.replyToMessageId!,
                        chatRoomId: message.chatRoomId,
                        senderId: message.replyToSenderId!,
                        receiverId: message.receiverId,
                        content: message.replyToContent!,
                        timestamp: message.timestamp,
                        status: MessageStatus.sent,
                        readBy: [],
                        replyToSenderName: message.replyToSenderName,
                        chatType: ChatType.group,
                      ),
                      currentUserId: currentUserId,
                      isPreview: false,
                      senderName: message.replyToSenderName,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isMe
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        // Show sender name inside bubble for all messages
                        if (message.senderName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              isMe ? "You" : message.senderName!,
                              style: TextStyle(
                                color:
                                    isMe
                                        ? Colors.white70
                                        : Theme.of(context).primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                              DateFormat(
                                'h:mm a',
                              ).format(message.timestamp.toDate()),
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
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );

    if (animation != null) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.scale(scale: animation.value, child: messageWidget);
        },
      );
    }

    return messageWidget;
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text("Reply"),
                  onTap: () {
                    Navigator.pop(context);
                    _groupChatCubit.setReplyToMessage(message);
                  },
                ),
                if (message.senderId == _currentUserId)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      "Delete",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Implement delete message
                    },
                  ),
              ],
            ),
          ),
    );
  }
}
