import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_client.dart';

/// High-priority push wake-up per the spec: sound + vibration, must wake a
/// killed app. Firebase project setup (google-services.json /
/// firebase_options.dart) is an infra step outside this codebase — see
/// mobile/README.md. Until it's added, initialize() fails safe: the app
/// keeps working off the WebSocket connection, it just won't wake in the
/// background.
class PushService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool ready = false;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      developer.log('Firebase not configured — push notifications disabled: $e', name: 'PushService');
      return;
    }

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    const channel = AndroidNotificationChannel(
      'valuation_requests',
      'Valuation requests',
      description: 'New bike valuation requests and results',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    final token = await messaging.getToken();
    if (token != null) await _uploadToken(token);
    messaging.onTokenRefresh.listen(_uploadToken);

    ready = true;
  }

  static Future<void> _uploadToken(String token) async {
    try {
      await ApiClient.instance.dio.patch('/me', data: {'fcmToken': token});
    } catch (e) {
      developer.log('Failed to upload FCM token: $e', name: 'PushService');
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'valuation_requests',
          'Valuation requests',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }
}
