import 'dart:io';

import 'package:chatzilla/data/models/chat_message.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/chat/chat_cubit.dart';
import 'package:chatzilla/logic/cubit/chat/chat_state.dart';
import 'package:chatzilla/presentation/widgets/reply_message_widget.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ChatMessageScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  const ChatMessageScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen>
    with TickerProviderStateMixin {
  final TextEditingController messageController = TextEditingController();
  late final ChatCubit _chatCubit;
  final _scrollController = ScrollController();
  List<ChatMessage> _previousMessages = [];
  bool _isComposing = false;
  bool _showEmoji = false;
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};

  @override
  void initState() {
    _chatCubit = getIt<ChatCubit>();
    print("receiver id ${widget.receiverId}");
    _chatCubit.enterChat(widget.receiverId);
    messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    _setUserOnline();

    super.initState();
  }

  void _setUserOnline() async {
    try {
      final currentUserId = _chatCubit.currentUserId;
      await getIt<ChatRepository>().updateOnlineStatus(currentUserId, true);
    } catch (e) {
      print("Error setting user online: $e");
    }
  }

  Future<void> _handleSendMessage() async {
    final messageText = messageController.text.trim();
    if (messageText.isEmpty) return;

    messageController.clear();
    setState(() {
      _isComposing = false;
    }); // Get current reply state
    final currentState = _chatCubit.state;
    final replyToMessage = currentState.replyingToMessage;

    // Determine the sender name for the reply
    String? replyToSenderName;
    if (replyToMessage != null) {
      if (replyToMessage.senderId == _chatCubit.currentUserId) {
        replyToSenderName = "You";
      } else if (replyToMessage.senderId == widget.receiverId) {
        replyToSenderName = widget.receiverName;
      } else {
        replyToSenderName = "Unknown User";
      }
    }

    // Send message
    await _chatCubit.sendMessage(
      content: messageText,
      receiverId: widget.receiverId,
      replyToMessage: replyToMessage,
      replyToSenderName: replyToSenderName,
    );

    // Clear reply after sending
    if (replyToMessage != null) {
      _chatCubit.clearReply();
    }

    // Immediate scroll for sent messages
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _chatCubit.loadMoreMessages();
    }
  }

  void _onTextChanged() {
    final isComposing = messageController.text.isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
      if (isComposing) {
        _chatCubit.startTyping();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400), // Smoother scroll duration
        curve: Curves.easeOutCubic, // Smoother curve for scrolling
      );
    }
  }

  void _hasNewMessages(List<ChatMessage> messages) {
    // Check for new messages and animate them
    for (final message in messages) {
      if (!_previousMessages.any((prev) => prev.id == message.id)) {
        _animateNewMessage(message);
        // Delay scroll to allow animation to start
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
    // Don't create animation if one already exists
    if (_animationControllers.containsKey(message.id)) {
      return;
    }

    final controller = AnimationController(
      duration: const Duration(
        milliseconds: 400,
      ), // Slightly longer for smoother animation
      vsync: this,
    );

    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut, // More bouncy and smooth curve
      ),
    );

    _animationControllers[message.id] = controller;
    _animations[message.id] = animation;

    // Add listener to clean up when animation completes
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Clean up after animation completes
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
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    messageController.dispose();
    _scrollController.dispose();
    _chatCubit.leaveChat();

    super.dispose();
  }

  // Add this helper method to group messages by date
  List<Widget> _buildMessageWidgets(List<ChatMessage> messages) {
    if (messages.isEmpty) return [];

    List<Widget> widgets = [];
    String? lastDateString;

    // Reverse the messages since ListView is reversed
    final reversedMessages = messages.reversed.toList();

    for (int i = 0; i < reversedMessages.length; i++) {
      final message = reversedMessages[i];
      final messageDate = message.timestamp.toDate();
      final dateString = _getDateString(messageDate);

      // Add date separator if this is a new date
      if (lastDateString != dateString) {
        widgets.add(_buildDateSeparator(dateString, messageDate));
        lastDateString = dateString;
      }
      final isMe = message.senderId == _chatCubit.currentUserId;
      widgets.add(
        AnimatedMessageBubble(
          key: ValueKey(message.id),
          message: message,
          isMe: isMe,
          currentUserId: _chatCubit.currentUserId,
          animation: _animations[message.id],
          onReply: (replyMessage) => _chatCubit.setReplyToMessage(replyMessage),
        ),
      );
    }

    return widgets.reversed.toList(); // Reverse back for the reversed ListView
  }

  String _getDateString(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(date.year, date.month, date.day);

    if (messageDay == today) {
      return 'Today';
    } else if (messageDay == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDay).inDays < 7) {
      return DateFormat(
        'EEEE',
      ).format(date); // Day name (Monday, Tuesday, etc.)
    } else {
      return DateFormat('MMM dd, yyyy').format(date); // Month Day, Year
    }
  }

  Widget _buildDateSeparator(String dateString, DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColorDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateString,
            style: TextStyle(
              color: Theme.of(context).scaffoldBackgroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
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
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColorDark,
              foregroundImage: NetworkImage(
                "https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.receiverName)}&background=${Theme.of(context).primaryColorDark.value.toRadixString(16).substring(2)}&color=fff",
              ),
              child: Text(
                widget.receiverName.runes.isNotEmpty
                    ? String.fromCharCode(
                      widget.receiverName.runes.first,
                    ).toUpperCase()
                    : "?",
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
                    widget.receiverName,
                    style: const TextStyle(
                      color: Color(0xFFF9F7F1),
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  BlocBuilder<ChatCubit, ChatState>(
                    bloc: _chatCubit,
                    builder: (context, state) {
                      if (state.amIBlocked || state.isUserBlocked) {
                        return const SizedBox.shrink();
                      }
                      if (state.isReceiverTyping) {
                        return Row(
                          children: [
                            Container(
                              foregroundDecoration: BoxDecoration(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                              ),
                              margin: const EdgeInsets.only(right: 4),
                              // child: LoadingDots(),
                            ),
                            Text(
                              "typing...",
                              style: TextStyle(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                              ),
                            ),
                          ],
                        );
                      }
                      if (state.isReceiverOnline) {
                        return const Text(
                          "Online ",
                          style: TextStyle(fontSize: 14, color: Colors.green),
                        );
                      }
                      if (state.receiverLastSeen != null) {
                        final lastSeen = state.receiverLastSeen!.toDate();
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final yesterday = today.subtract(
                          const Duration(days: 1),
                        );
                        final lastSeenDay = DateTime(
                          lastSeen.year,
                          lastSeen.month,
                          lastSeen.day,
                        );
                        final time = DateFormat('h:mm a').format(lastSeen);

                        String lastSeenText;
                        if (lastSeenDay == today) {
                          lastSeenText = 'last seen at $time';
                        } else if (lastSeenDay == yesterday) {
                          lastSeenText = 'last seen yesterday at $time';
                        } else {
                          final date = DateFormat('MMM dd').format(lastSeen);
                          lastSeenText = 'last seen on $date at $time';
                        }

                        return Text(
                          lastSeenText,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<ChatCubit, ChatState>(
            bloc: _chatCubit,
            builder: (context, state) {
              if (state.isUserBlocked) {
                return TextButton.icon(
                  onPressed: () => _chatCubit.unBlockUser(widget.receiverId),
                  label: const Text("Unblock"),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.block),
                );
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == "block") {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(
                              'Block User',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                                fontSize: 20,
                              ),
                            ),
                            content: Text(
                              "Are you sure you want to block ${widget.receiverName}?",
                              style: const TextStyle(fontSize: 16),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Block',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    );
                    if (confirm == true) {
                      await _chatCubit.blockUser(widget.receiverId);
                    }
                  }
                },
                itemBuilder:
                    (context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem(
                        value: 'block',
                        child: Text("Block User"),
                      ),
                    ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ChatCubit, ChatState>(
        listener: (context, state) {
          _hasNewMessages(state.messages);
        },
        bloc: _chatCubit,
        builder: (context, state) {
          if (state.status == ChatStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ChatStatus.error) {
            return Center(child: Text(state.error ?? "Something went wrong"));
          }

          return Container(
            color: const Color(0xFFECF2F4),
            child: Column(
              children: [
                if (state.amIBlocked)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withOpacity(0.1),
                    child: Text(
                      "You have been blocked by ${widget.receiverName}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    children: _buildMessageWidgets(state.messages),
                  ),
                ),
                if (!state.amIBlocked && !state.isUserBlocked)
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
                                currentUserId: _chatCubit.currentUserId,
                                isPreview: true,
                                onCancel: () => _chatCubit.clearReply(),
                                senderName:
                                    state.replyingToMessage?.senderId ==
                                            _chatCubit.currentUserId
                                        ? "You"
                                        : state.replyingToMessage?.senderId ==
                                            widget.receiverId
                                        ? widget.receiverName
                                        : "Unknown User",
                              ),
                            ),
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.end, // Align to bottom
                            children: [
                              Expanded(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxHeight:
                                        120, // Maximum height (about 6 lines)
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
                                    maxLines: null, // Allow unlimited lines
                                    minLines: 1, // Start with 1 line
                                    textInputAction:
                                        TextInputAction
                                            .newline, // Allow new lines
                                    decoration: InputDecoration(
                                      hintText: "Type a message",
                                      filled: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                        color:
                                            Theme.of(context).primaryColorDark,
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
                                        Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                    loadingIndicator: const SizedBox.shrink(),
                                  ),
                                  categoryViewConfig: const CategoryViewConfig(
                                    initCategory: Category.RECENT,
                                  ),
                                  bottomActionBarConfig: BottomActionBarConfig(
                                    enabled: true,
                                    backgroundColor:
                                        Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
                                    buttonColor: Theme.of(context).primaryColor,
                                  ),
                                  skinToneConfig: const SkinToneConfig(
                                    enabled: true,
                                    dialogBackgroundColor: Colors.white,
                                    indicatorColor: Colors.grey,
                                  ),
                                  searchViewConfig: SearchViewConfig(
                                    backgroundColor:
                                        Theme.of(
                                          context,
                                        ).scaffoldBackgroundColor,
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
}

class AnimatedMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final Animation<double>? animation;
  final String currentUserId;
  final Function(ChatMessage)? onReply;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.animation,
    this.onReply,
  });
  @override
  Widget build(BuildContext context) {
    if (animation == null) {
      return MessageBubble(
        message: message,
        isMe: isMe,
        currentUserId: currentUserId,
        onReply: onReply,
      );
    }

    return AnimatedBuilder(
      animation: animation!,
      builder: (context, child) {
        final animationValue = animation!.value.clamp(0.0, 1.0);

        return Transform.scale(
          scale:
              0.7 +
              (animationValue * 0.3), // Start from 70% size, scale to 100%
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Transform.translate(
            offset: Offset(
              isMe
                  ? (1 - animationValue) * 30
                  : (1 - animationValue) * -30, // Reduced slide distance
              (1 - animationValue) * 20, // Add slight vertical slide
            ),
            child: Opacity(
              opacity: animationValue,
              child: MessageBubble(
                message: message,
                isMe: isMe,
                currentUserId: currentUserId,
                onReply: onReply,
              ),
            ),
          ),
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String currentUserId;
  final Function(ChatMessage)? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    this.onReply,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => onReply?.call(message),
      child: Dismissible(
        key: Key(message.id),
        direction:
            isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          onReply?.call(message);
          return false; // Don't actually dismiss
        },
        background: Container(
          color: Colors.transparent,
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          padding: EdgeInsets.only(left: isMe ? 0 : 20, right: isMe ? 20 : 0),
          child: Icon(
            Icons.reply,
            color: Theme.of(context).primaryColor,
            size: 24,
          ),
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                // Show reply if this message is a reply
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
      ),
    );
  }
}
