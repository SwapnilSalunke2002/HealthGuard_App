import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request Permission from OS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true, criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Get the unique device token
      String? token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToSupabase(token);
      }

      // 3. Listen for token refreshes
      _messaging.onTokenRefresh.listen(_saveTokenToSupabase);

      // 4. Listen for incoming messages while app is OPEN
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(message.notification!.title, message.notification!.body);
        }
      });
    }
  }

  static Future<void> _saveTokenToSupabase(String fcmToken) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    // Upload the token to your Supabase users table
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': fcmToken})
          .eq('firebase_uid', userId);
    } catch (e) {
      print("Failed to save FCM token: $e");
    }
  }

  static Future<void> _showLocalNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'healthguard_critical', 'Health Alerts',
      importance: Importance.max, priority: Priority.high, color: Color(0xFFFF1744),
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    // 🚀 FIXED: Using named parameters instead of positional!
    await _localNotifications.show(
      id: 0, 
      title: title, 
      body: body, 
      notificationDetails: platformDetails,
    );
  }
}