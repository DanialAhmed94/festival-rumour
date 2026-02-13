import 'dart:convert';
import 'package:festival_rumour/core/services/storage_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // 🔔 Permission (iOS + Android 13+)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 📱 Get & save FCM token (simple & safe)
    await _getAndSaveToken();

    // 🔁 Always listen for refresh (this guarantees correctness)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('🔁 FCM Token refreshed: $newToken');
      await StorageService().setFcmToken(newToken);
    });

    // ✅ FOREGROUND messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // ✅ Background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // ✅ Terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  static Future<String?> _getAndSaveToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    print("FCM TOKEN FETCHED: $token");

    if (token != null) {
      print('✅ FCM Token: $token');
      await StorageService().setFcmToken(token);
      return token;
    }
    // try {

    // } catch (e) {
    //   print('❌ FCM token error: $e');
    // }

    // return null;
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    NotificationService.show(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  static void _onMessageOpened(RemoteMessage message) {
    _handleMessage(message);
  }

  static void _handleMessage(RemoteMessage message) {
    print('📩 Notification clicked with data: ${message.data}');
  }
}
