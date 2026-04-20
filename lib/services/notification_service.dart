// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ Handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Navigation key untuk navigate dari notification
  static GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;

    // Setup background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    await _requestPermission();

    // Setup local notifications
    await _setupLocalNotifications();

    // Get & save FCM token
    await _saveFcmToken();

    // Listen untuk token refresh
    _messaging.onTokenRefresh.listen(_saveToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap bila app background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap bila app terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('FCM Permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle tap pada local notification
        if (details.payload != null) {
          _navigateToPost(details.payload!);
        }
      },
    );

    // Create notification channel untuk Android
    const channel = AndroidNotificationChannel(
      'bantunow_channel',
      'BantuNow Notifications',
      description: 'Notifikasi request bantuan baru',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _saveFcmToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcm_token': token});

    print('FCM Token saved: $token');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final postId = message.data['post_id'] ?? '';

    // Tunjuk local notification
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'bantunow_channel',
          'BantuNow Notifications',
          channelDescription: 'Notifikasi request bantuan baru',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: postId,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final postId = message.data['post_id'];
    if (postId != null) {
      _navigateToPost(postId);
    }
  }

  void _navigateToPost(String postId) async {
    if (navigatorKey?.currentState == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('bantuan')
          .doc(postId)
          .get();

      if (!doc.exists) return;

      // Navigate ke detail screen
      navigatorKey!.currentState!.pushNamed(
        '/post-detail',
        arguments: {'postId': postId, 'data': doc.data()},
      );
    } catch (e) {
      print('Error navigate to post: $e');
    }
  }

  // ✅ Update FCM token bila user login
  Future<void> onUserLogin() async {
    await _saveFcmToken();
  }

  // ✅ Remove FCM token bila user logout
  Future<void> onUserLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcm_token': FieldValue.delete()});

    await _messaging.deleteToken();
  }
}