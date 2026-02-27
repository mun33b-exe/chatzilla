import 'dart:developer';

import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
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
}
