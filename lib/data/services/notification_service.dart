import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  // ── Backend server URL ────────────────────────────────────────────────
  // For local testing, use your machine's local IP (not localhost/127.0.0.1)
  // e.g. 'http://192.168.1.100:3000'
  //
  // For production, replace with your Render.com URL:
  // e.g. 'https://chatzilla-notifications.onrender.com'
  static const String _baseUrl = 'https://chatzilla-backend-b9f198d7e15f.herokuapp.com';

  /// Initialize OneSignal with your App ID.
  /// Call this once at app startup (e.g. inside setupServiceLocator).
  void initialize(String appId) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(appId);
    OneSignal.Notifications.requestPermission(true);
    log('[NotificationService] OneSignal initialized with appId: $appId');
  }

  /// Returns the current OneSignal Subscription ID (player ID).
  /// This is the identifier used to target a specific device via the REST API.
  /// Returns null if the user hasn't subscribed yet.
  String? getSubscriptionId() {
    return OneSignal.User.pushSubscription.id;
  }

  /// Send an individual chat notification via the backend server.
  Future<void> sendIndividualNotification({
    required String senderName,
    required String content,
    required String subscriptionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/individual'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderName': senderName,
          'content': content,
          'subscriptionId': subscriptionId,
        }),
      );

      if (response.statusCode == 200) {
        log('[NotificationService] Individual notification sent successfully');
      } else {
        log(
          '[NotificationService] Individual notification failed: ${response.body}',
        );
      }
    } catch (e) {
      log('[NotificationService] Error sending individual notification: $e');
    }
  }

  /// Send a group chat notification via the backend server.
  Future<void> sendGroupNotification({
    required String groupName,
    required String senderName,
    required String content,
    required List<String> subscriptionIds,
  }) async {
    try {
      if (subscriptionIds.isEmpty) {
        log(
          '[NotificationService] No subscription IDs — skipping group notification',
        );
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/group'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupName': groupName,
          'senderName': senderName,
          'content': content,
          'subscriptionIds': subscriptionIds,
        }),
      );

      if (response.statusCode == 200) {
        log('[NotificationService] Group notification sent successfully');
      } else {
        log(
          '[NotificationService] Group notification failed: ${response.body}',
        );
      }
    } catch (e) {
      log('[NotificationService] Error sending group notification: $e');
    }
  }
}
