import 'dart:io';

import 'package:chatzilla/data/models/chat_message.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/chat/chat_cubit.dart';
import 'package:chatzilla/logic/cubit/chat/chat_state.dart';
import 'package:chatzilla/presentation/widgets/loading_dots.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final TextEditingController messageController = TextEditingController();
  late final ChatCubit _chatCubit;
  final _scrollController = ScrollController();
  List<ChatMessage> _previousMessages = [];
  bool _isComposing = false;
  bool _showEmoji = false;

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
    messageController.clear();
    await _chatCubit.sendMessage(
      content: messageText,
      receiverId: widget.receiverId,
    );
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _hasNewMessages(List<ChatMessage> messages) {
    if (messages.length != _previousMessages.length) {
      _scrollToBottom();
      _previousMessages = messages;
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    _chatCubit.leaveChat();

    super.dispose();
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
                "https://ui-avatars.com/api/?name=${widget.receiverName}&background=${Theme.of(context).primaryColorDark.value.toRadixString(16).substring(2)}&color=fff",
              ),
              child: Text(
                widget.receiverName[0].toUpperCase(),
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
                      // Hide activity status if either user is blocked
                      if (state.amIBlocked || state.isUserBlocked) {
                        return const SizedBox.shrink();
                      }
                      if (state.isReceiverTyping) {
                        return Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              child: const LoadingDots(),
                            ),
                            Text(
                              "typing",
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
                        return Text(
                          "last seen at ${DateFormat('h:mm a').format(lastSeen)}",
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
                              "Are you sure you want to block ${widget.receiverName}",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  "Block",
                                  style: TextStyle(color: Colors.red),
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
            Center(child: Text(state.error ?? "Something went wrong"));
          }
          return Container(
            color: const Color(0xFFECF2F4), // Set chat background color here
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
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final isMe = message.senderId == _chatCubit.currentUserId;
                      return MessageBubble(message: message, isMe: isMe);
                    },
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
                          Row(
                            children: [
                              Expanded(
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

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  // final bool showTime;
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    // required this.showTime,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 64 : 8,
          right: isMe ? 8 : 64,
          bottom: 4,
        ),
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
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.timestamp.toDate()),
                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
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
    );
  }
}
