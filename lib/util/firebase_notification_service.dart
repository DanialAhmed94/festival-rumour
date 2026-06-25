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
import 'notification_service.dart';

class NotificationLaunchTarget {
  final String routeName;
  final Object? arguments;

  const NotificationLaunchTarget({
    required this.routeName,
    this.arguments,
  });
}

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

  /// Pending data from a terminated-state notification tap (cold start).
  /// Does not clear; use [consumePendingNotificationData] after the navigator is ready.
  static Map<String, dynamic>? peekPendingNotificationData() =>
      _pendingNotificationData;

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

    final dataChatRoomId =
        CurrentChatRoomService.normalizeChatRoomId(message.data['chatRoomId']);

    bool viewingThisRoom = false;
    try {
      if (locator.isRegistered<CurrentChatRoomService>()) {
        viewingThisRoom = locator<CurrentChatRoomService>().isViewingChatRoom(
          message.data['chatRoomId'],
        );
      }
    } catch (_) {}

    print('[NOTIF] Device: dataChatRoomId=$dataChatRoomId viewingThisRoom=$viewingThisRoom');

    if (viewingThisRoom) {
      print('[NOTIF] Device: suppress - user is open on this chat (no tray; use in-thread UI)');
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
      NotificationStorageService.persistFromRemoteMessage(message).then((_) async {
        if (locator.isRegistered<NotificationStorageService>()) {
          await locator<NotificationStorageService>().reloadAfterExternalPersist();
        }
      });
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

  /// Maps FCM data to an initial route (cold start). No auth check.
  static NotificationLaunchTarget? parseLaunchTargetFromData(
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String?;
    if (type == 'referral_joined' || type == 'badge_earned') {
      return const NotificationLaunchTarget(routeName: AppRoutes.invite);
    }
    if (type == 'post_comment' || type == 'comment_reply') {
      final postId = data['postId'] as String?;
      final collectionName = data['collectionName'] as String?;
      if (postId != null &&
          postId.isNotEmpty &&
          collectionName != null &&
          collectionName.isNotEmpty) {
        final parentCommentId = data['parentCommentId'] as String?;
        return NotificationLaunchTarget(
          routeName: AppRoutes.commentDeepLink,
          arguments: <String, dynamic>{
            'postId': postId,
            'collectionName': collectionName,
            if (type == 'comment_reply' &&
                parentCommentId != null &&
                parentCommentId.isNotEmpty)
              'focusCommentId': parentCommentId,
          },
        );
      }
    }

    final chatRoomId = data['chatRoomId'] as String?;
    if (chatRoomId == null || chatRoomId.isEmpty) return null;

    final festivalId = data['festivalId'] as String?;
    final hasFestival = festivalId != null && festivalId.isNotEmpty;

    if (hasFestival) {
      return NotificationLaunchTarget(
        routeName: AppRoutes.chatRoom,
        arguments: chatRoomId,
      );
    }
    return NotificationLaunchTarget(
      routeName: AppRoutes.directChat,
      arguments: {'chatRoomId': chatRoomId},
    );
  }

  static void _navigateLaunchTarget(NotificationLaunchTarget target) {
    if (!locator.isRegistered<NavigationService>()) {
      print('[NOTIF] Nav: NavigationService not registered, skip');
      return;
    }
    final navService = locator<NavigationService>();
    print('[NOTIF] Nav: pushing ${target.routeName}');
    navService.navigateTo(target.routeName, arguments: target.arguments);
  }

  /// Deep-link route names that receive singleton stack management.
  /// Covers both chat screens and comment screens so neither can stack.
  /// Kept as a plain (non-const) set because class-static const strings are
  /// not considered compile-time constants for Set literals in Dart.
  static final Set<String> _deepLinkRouteNames = {
    // Chat
    AppRoutes.chatRoom,
    AppRoutes.directChat,
    AppRoutes.chatRoomDetail,
    // Comments (CommentDeepLinkView replaces itself with the actual CommentView)
    AppRoutes.commentDeepLink,
    AppRoutes.comments,
  };

  /// Chat-only routes — used to scope the CurrentChatRoomService guard.
  static final Set<String> _chatRouteNames = {
    AppRoutes.chatRoom,
    AppRoutes.directChat,
  };

  /// Navigate to the correct screen based on FCM data payload.
  ///
  /// [preserveStack] controls back-navigation behaviour:
  ///   • false (default) — background/system-notification tap: pop down to the
  ///     festival screen first, then push the target.  Back = festivals.
  ///   • true — foreground/in-app tap: push the target on top of whatever the
  ///     user is currently looking at.  Back = wherever the user already was.
  ///
  /// Singleton rules (apply in both modes):
  ///   • Already on this exact chat room → no-op.
  ///   • Stale deep-link screens → popped before pushing.
  static void navigateFromNotificationData(
    Map<String, dynamic> data, {
    bool preserveStack = false,
  }) {
    final target = parseLaunchTargetFromData(data);
    if (target == null) {
      print('[NOTIF] Nav: no recognized deep link in data, skip navigation');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[NOTIF] Nav: user not logged in, skip navigation');
      return;
    }

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

      final isDeepLinkRoute = _deepLinkRouteNames.contains(target.routeName);

      if (isDeepLinkRoute) {
        // Guard 1 (chat only): user is already viewing the exact same room — nothing to do.
        // Comment screens don't have an equivalent tracking service; re-pushing
        // a comment screen is acceptable (refreshes to latest data).
        if (_chatRouteNames.contains(target.routeName)) {
          final targetRoomId = CurrentChatRoomService.normalizeChatRoomId(
            data['chatRoomId'],
          );
          if (targetRoomId != null) {
            try {
              if (locator.isRegistered<CurrentChatRoomService>() &&
                  locator<CurrentChatRoomService>().isViewingChatRoom(targetRoomId)) {
                print('[NOTIF] Nav: already viewing room $targetRoomId — skip push');
                return;
              }
            } catch (_) {}
          }
        }

        if (preserveStack) {
          // Foreground / in-app tap: the user was actively using the app.
          // Only remove stale deep-link screens (prevents stacking); keep
          // everything else so back returns them to where they were.
          navigator.popUntil(
            (route) =>
                route.isFirst ||
                !_deepLinkRouteNames.contains(route.settings.name),
          );
          print('[NOTIF] Nav: foreground tap — popped stale deep-link routes, preserving stack');
        } else {
          // Background / system-notification tap: rebuild the back-stack so
          // pressing back always goes to the festival screen, not home/navbaar.
          navigator.popUntil(
            (route) =>
                route.isFirst ||
                route.settings.name == AppRoutes.festivals,
          );
          print('[NOTIF] Nav: background tap — popped to festivals → pushing ${target.routeName}');
        }
      }

      _navigateLaunchTarget(target);
    } catch (e) {
      print('[NOTIF] Nav: error during navigation: $e');
    }
  }
}
