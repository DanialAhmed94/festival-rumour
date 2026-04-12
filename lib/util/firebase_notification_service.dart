import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:festival_rumour/core/di/locator.dart';
import 'package:festival_rumour/core/router/app_router.dart';
import 'package:festival_rumour/core/services/chat_badge_service.dart';
import 'package:festival_rumour/core/services/current_chat_room_service.dart';
import 'package:festival_rumour/core/services/navigation_service.dart';
import 'package:festival_rumour/core/services/notification_storage_service.dart';
import 'package:festival_rumour/core/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'notification_service.dart';

class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Holds notification data from a terminated-state launch so we can navigate
  /// after the main MaterialApp + navigator are ready.
  static Map<String, dynamic>? _pendingNotificationData;

  /// Returns and clears the pending notification data (if any).
  static Map<String, dynamic>? consumePendingNotificationData() {
    final data = _pendingNotificationData;
    _pendingNotificationData = null;
    return data;
  }

  static Future<void> init() async {
    await _getAndSaveToken();

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('[NOTIF] Device: FCM token refreshed');
      await StorageService().setFcmToken(newToken);
      await _updateFcmTokenInFirestore(newToken);
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // Terminated-state: app was killed, user tapped notification to launch it.
    // Navigator is not ready yet, so store the data for later consumption.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('[NOTIF] Device: terminated-state initial message, data=${initialMessage.data}');
      _addToNotificationList(initialMessage);
      _pendingNotificationData = Map<String, dynamic>.from(initialMessage.data);
    }

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await StorageService().getFcmToken();
        if (token != null) await _updateFcmTokenInFirestore(token);
      }
    });

    final stored = await StorageService().getNotificationsEnabled();
    if (stored == null) {
      final settings = await _messaging.getNotificationSettings();
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      await StorageService().setNotificationsEnabled(granted);
    }

    print('[NOTIF] Device: FCM init done, listening for messages');
  }

  /// Call this when you want to show the notification permission prompt (e.g. on festival screen).
  static Future<void> requestPermissionIfNeeded() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    await StorageService().setNotificationsEnabled(granted);
    if (granted) await _getAndSaveToken();
  }

  static Future<String?> _getAndSaveToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    print("[NOTIF] Device: FCM token fetched: ${token != null ? 'yes' : 'null'}");

    if (token != null) {
      await StorageService().setFcmToken(token);
      await _updateFcmTokenInFirestore(token);
      return token;
    }
    return null;
  }

  /// Write FCM token to Firestore so Cloud Function can send to this user.
  /// Only runs when user is logged in.
  static Future<void> _updateFcmTokenInFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[NOTIF] Device: skip Firestore update - no logged-in user');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'appIdentifier': 'festivalrumor',
      }, SetOptions(merge: true));
      print('[NOTIF] Device: FCM token written to Firestore for ${user.uid}');
    } catch (e) {
      print('[NOTIF] Device: failed to write FCM token to Firestore: $e');
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    print('[NOTIF] Device: foreground FCM received, messageId=${message.messageId}, data=${message.data}');
    StorageService().getNotificationsEnabled().then((enabled) {
      if (enabled != true) {
        print('[NOTIF] Device: skip - notifications disabled or not yet synced');
        return;
      }
      _onForegroundMessageImpl(message);
    });
  }

  static void _onForegroundMessageImpl(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      print('[NOTIF] Device: skip show - no notification payload (data-only message)');
      return;
    }

    final dataChatRoomId = message.data['chatRoomId'] as String?;
    String? currentRoom;
    try {
      if (locator.isRegistered<CurrentChatRoomService>()) {
        currentRoom = locator<CurrentChatRoomService>().currentChatRoomId;
      }
    } catch (_) {}

    print('[NOTIF] Device: dataChatRoomId=$dataChatRoomId currentRoom=$currentRoom match=${dataChatRoomId != null && currentRoom != null && dataChatRoomId == currentRoom}');

    if (dataChatRoomId != null && dataChatRoomId.isNotEmpty && currentRoom != null && currentRoom == dataChatRoomId) {
      print('[NOTIF] Device: suppress - user is viewing this room (chatRoomId=$dataChatRoomId)');
      return;
    }

    final isPublicRoom = dataChatRoomId != null &&
        dataChatRoomId.isNotEmpty &&
        dataChatRoomId.endsWith('_PublicChat');

    if (dataChatRoomId != null && dataChatRoomId.isNotEmpty) {
      try {
        if (locator.isRegistered<ChatBadgeService>()) {
          locator<ChatBadgeService>().incrementBadge(dataChatRoomId);
        }
      } catch (_) {}
    }

    if (isPublicRoom) {
      return;
    }

    print('[NOTIF] Device: showing notification title="${notification.title}" body="${notification.body}"');
    _addToNotificationList(message);
    NotificationService.show(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  static void _addToNotificationList(RemoteMessage message) {
    try {
      if (!locator.isRegistered<NotificationStorageService>()) return;
      final notif = message.notification;
      final title = notif?.title ?? 'Notification';
      final body = notif?.body ?? '';
      final id = message.messageId ?? '${DateTime.now().millisecondsSinceEpoch}';
      final chatRoomId = message.data['chatRoomId'] as String?;
      locator<NotificationStorageService>().addNotification(
        id: id,
        title: title,
        message: body,
        chatRoomId: chatRoomId,
        type: chatRoomId != null ? 'chat' : 'general',
      );
    } catch (_) {}
  }

  static void _onMessageOpened(RemoteMessage message) {
    print('[NOTIF] Device: notification opened (app was in background)');
    _addToNotificationList(message);
    _handleMessage(message);
  }

  static void _handleMessage(RemoteMessage message) {
    print('[NOTIF] Device: handleMessage / tap, data=${message.data}');
    navigateFromNotificationData(Map<String, dynamic>.from(message.data));
  }

  /// Navigate to the correct chat screen based on FCM data payload.
  /// Called from FCM tap handler (background) and local notification tap handler.
  static void navigateFromNotificationData(Map<String, dynamic> data) {
    final chatRoomId = data['chatRoomId'] as String?;
    if (chatRoomId == null || chatRoomId.isEmpty) {
      print('[NOTIF] Nav: no chatRoomId in data, skip navigation');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[NOTIF] Nav: user not logged in, skip navigation');
      return;
    }

    final festivalId = data['festivalId'] as String?;
    final hasFestival = festivalId != null && festivalId.isNotEmpty;

    print('[NOTIF] Nav: chatRoomId=$chatRoomId, festivalId=$festivalId, hasFestival=$hasFestival');

    try {
      if (!locator.isRegistered<NavigationService>()) {
        print('[NOTIF] Nav: NavigationService not registered, skip');
        return;
      }
      final navService = locator<NavigationService>();
      final navigator = navService.navigatorKey.currentState;

      if (navigator == null) {
        print('[NOTIF] Nav: navigator not ready, storing as pending');
        _pendingNotificationData = data;
        return;
      }

      if (hasFestival) {
        print('[NOTIF] Nav: navigating to chatRoom (private chatroom)');
        navService.navigateTo(
          AppRoutes.chatRoom,
          arguments: chatRoomId,
        );
      } else {
        print('[NOTIF] Nav: navigating to directChat (DM)');
        navService.navigateTo(
          AppRoutes.directChat,
          arguments: {'chatRoomId': chatRoomId},
        );
      }
    } catch (e) {
      print('[NOTIF] Nav: error during navigation: $e');
    }
  }
}
