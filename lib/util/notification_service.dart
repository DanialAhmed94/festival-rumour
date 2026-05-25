import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_notification_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Small slot: white silhouette (drawable). Tray: full-color launcher mipmaps.
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    // ✅ ANDROID 8+ CHANNELS (default_channel + chat_messages for FCM from Cloud Function)
    const defaultChannel = AndroidNotificationChannel(
      'default_channel',
      'General Notifications',
      description: 'General notifications',
      importance: Importance.high,
    );
    await androidPlugin?.createNotificationChannel(defaultChannel);

    const chatChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
    );
    await androidPlugin?.createNotificationChannel(chatChannel);
  }

  static Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General Notifications',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      color: const Color(0xFFFC2E95),
      // largeIcon removed — it caused a second app icon to appear on the right
      // side of foreground notifications. Terminated-state FCM notifications
      // never set a largeIcon, so this keeps both paths visually consistent.
      // largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    print('[NOTIF] Local: notification tapped, payload=${response.payload}');
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = Map<String, dynamic>.from(
        jsonDecode(payload) as Map,
      );
      // App was in foreground when this notification was tapped — preserve the
      // current navigation stack so back returns the user to where they were.
      FirebaseNotificationService.navigateFromNotificationData(
        data,
        preserveStack: true,
      );
    } catch (e) {
      print('[NOTIF] Local: failed to parse payload: $e');
    }
  }
}
