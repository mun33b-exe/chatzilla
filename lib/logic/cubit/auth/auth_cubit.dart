import 'dart:async';
import 'dart:developer';

import 'package:chatzilla/data/repositories/auth_repository.dart';
import 'package:chatzilla/data/repositories/chat_repository.dart';
import 'package:chatzilla/data/services/notification_service.dart';
import 'package:chatzilla/data/services/service_locator.dart';
import 'package:chatzilla/logic/cubit/auth/auth_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final ChatRepository _chatRepository = getIt<ChatRepository>();
  final NotificationService _notificationService = getIt<NotificationService>();
  StreamSubscription<User?>? _authStateSubscription;

  AuthCubit({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState()) {
    _init();
  }

  /// Saves the OneSignal Subscription ID to the user's Firestore document.
  Future<void> _saveSubscriptionId(String uid) async {
    try {
      final subscriptionId = _notificationService.getSubscriptionId();
      if (subscriptionId != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': subscriptionId,
        });
        log('[AuthCubit] Saved OneSignal subscription ID for user: $uid');
      } else {
        log('[AuthCubit] OneSignal subscription ID is null — skipping save');
      }
    } catch (e) {
      log('[AuthCubit] Failed to save subscription ID: $e');
    }
  }

  /// Clears the fcmToken from the user's Firestore document on sign-out.
  Future<void> _clearSubscriptionId(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': null,
      });
      log('[AuthCubit] Cleared fcmToken for user: $uid');
    } catch (e) {
      log('[AuthCubit] Failed to clear fcmToken: $e');
    }
  }

  void _init() {
    emit(state.copyWith(status: AuthStatus.initial));

    _authStateSubscription = _authRepository.authStateChanges.listen((
      user,
    ) async {
      if (user != null) {
        try {
          final userData = await _authRepository.getUserData(user.uid);
          emit(
            state.copyWith(status: AuthStatus.authenticated, user: userData),
          );
          // Save OneSignal subscription ID on session restoration
          await _saveSubscriptionId(user.uid);
        } catch (e) {
          emit(state.copyWith(status: AuthStatus.error, error: e.toString()));
        }
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
      }
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      emit(state.copyWith(status: AuthStatus.loading));

      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );

      emit(state.copyWith(status: AuthStatus.authenticated, user: user));

      // Save OneSignal subscription ID after sign-in
      await _saveSubscriptionId(user.uid);
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> signUp({
    required String email,
    required String username,
    required String fullName,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      emit(state.copyWith(status: AuthStatus.loading));

      final user = await _authRepository.signUp(
        fullName: fullName,
        username: username,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      emit(state.copyWith(status: AuthStatus.authenticated, user: user));

      // Save OneSignal subscription ID after sign-up
      await _saveSubscriptionId(user.uid);
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.error, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      // Set user offline before signing out
      final currentUserId = _authRepository.currentUser?.uid;
      if (currentUserId != null) {
        await _chatRepository.updateOnlineStatus(currentUserId, false);
        // Clear the OneSignal subscription ID so logged-out devices
        // no longer receive push notifications.
        await _clearSubscriptionId(currentUserId);
      }

      await _authRepository.singOut();
      emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.error, error: e.toString()));
    }
  }
}
