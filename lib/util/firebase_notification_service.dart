import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:festival_rumour/core/di/locator.dart';
import 'package:festival_rumour/core/services/chat_badge_service.dart';
import 'package:festival_rumour/core/services/current_chat_room_service.dart';
import 'package:festival_rumour/core/services/notification_storage_service.dart';
import 'package:festival_rumour/core/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // 🔔 Permission (iOS + Android 13+)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 📱 Get & save FCM token (local + Firestore so Cloud Function can send to this device)
    await _getAndSaveToken();

    // 🔁 Always listen for refresh (this guarantees correctness)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('[NOTIF] Device: FCM token refreshed');
      await StorageService().setFcmToken(newToken);
      await _updateFcmTokenInFirestore(newToken);
    });

    // ✅ FOREGROUND messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // ✅ Background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // ✅ Terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _addToNotificationList(initialMessage);
      _handleMessage(initialMessage);
    }

    // When user logs in or session restores, write token to Firestore so Cloud Function can send to this device
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final token = await StorageService().getFcmToken();
        if (token != null) await _updateFcmTokenInFirestore(token);
      }
    });

    // Sync stored preference with actual permission when never set (default = permission state).
    final stored = await StorageService().getNotificationsEnabled();
    if (stored == null) {
      final settings = await _messaging.getNotificationSettings();
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      await StorageService().setNotificationsEnabled(granted);
    }

    print('[NOTIF] Device: FCM init done, listening for messages');
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

    if (dataChatRoomId != null && dataChatRoomId.isNotEmpty && currentRoom != null && currentRoom == dataChatRoomId) {
      print('[NOTIF] Device: suppress - user is viewing this room (chatRoomId=$dataChatRoomId)');
      return;
    }

    print('[NOTIF] Device: showing notification title="${notification.title}" body="${notification.body}"');
    if (dataChatRoomId != null && dataChatRoomId.isNotEmpty) {
      try {
        if (locator.isRegistered<ChatBadgeService>()) {
          locator<ChatBadgeService>().incrementBadge(dataChatRoomId);
        }
      } catch (_) {}
    }
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
  }
}
