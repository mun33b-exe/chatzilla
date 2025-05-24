import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';

class AppLifeCycleObserver extends WidgetsBindingObserver {
  final String userId;
  final ChatRepository chatRepository;

  AppLifeCycleObserver({required this.userId, required this.chatRepository});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // Set user offline when app goes to background
        chatRepository.updateOnlineStatus(userId, false);
        break;
      case AppLifecycleState.resumed:
        // Set user online when app comes to foreground
        chatRepository.updateOnlineStatus(userId, true);
        break;
      default:
        break;
    }
  }
}
