import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.initLocalOnly();

  // Android/iOS notification payload ko background/terminated state me system
  // khud show karta hai. Data-only push ke liye local notification show karte hain.
  if (message.notification != null) return;

  final title = message.data['title'] ?? 'Daily Kharcha';
  final body = message.data['body'] ??
      message.data['message'] ??
      'New notification received';

  if (title.toString().trim().isNotEmpty || body.toString().trim().isNotEmpty) {
    await NotificationService.showAdminNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.toString(),
      body: body.toString(),
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _localInitialized = false;
  static bool _fcmListenersAttached = false;

  static const AndroidNotificationChannel _adminChannel = AndroidNotificationChannel(
    'daily_kharcha_admin_alerts',
    'Daily Kharcha Alerts',
    description: 'Admin updates and important app alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _reminderChannel = AndroidNotificationChannel(
    'daily_kharcha_reminder_channel',
    'Daily Kharcha Reminders',
    description: 'Daily transaction reminder notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (kIsWeb) return;

    await initLocalOnly();
    await _initFirebaseMessaging();
  }

  static Future<void> initLocalOnly() async {
    if (kIsWeb || _localInitialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_adminChannel);
    await androidPlugin?.createNotificationChannel(_reminderChannel);
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _localInitialized = true;
  }

  static Future<void> _initFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await syncFcmTokenForCurrentUser();

    if (_fcmListenersAttached) return;
    _fcmListenersAttached = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] ?? 'Daily Kharcha';
      final body = notification?.body ??
          message.data['body'] ??
          message.data['message'] ??
          'New notification received';

      await showAdminNotification(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.toString(),
        body: body.toString(),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await syncFcmTokenForCurrentUser();
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _saveFcmToken(token);
    });
  }

  static Future<void> syncFcmTokenForCurrentUser() async {
    if (kIsWeb) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await _saveFcmToken(token);
    } catch (e) {
      debugPrint('FCM token sync skipped: $e');
    }
  }

  static Future<void> _saveFcmToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token.trim().isEmpty) return;

    final now = FieldValue.serverTimestamp();
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await userRef.set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'fcmTokenUpdatedAt': now,
    }, SetOptions(merge: true));

    await userRef.collection('fcmTokens').doc(token).set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('fcmTokens').doc(token).set({
      'token': token,
      'uid': user.uid,
      'email': user.email ?? '',
      'platform': defaultTargetPlatform.name,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  static Future<void> showAdminNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    await initLocalOnly();

    final int notificationId = id.hashCode & 0x7fffffff;

    await _notificationsPlugin.show(
      notificationId,
      title.trim().isEmpty ? 'Daily Kharcha' : title.trim(),
      body.trim().isEmpty ? 'New notification received' : body.trim(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_kharcha_admin_alerts',
          'Daily Kharcha Alerts',
          channelDescription: 'Admin updates and important app alerts',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: false,
          ticker: 'Daily Kharcha Alert',
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: id,
    );
  }

  static Future<void> scheduleAdminNotificationAt({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (kIsWeb) return;

    await initLocalOnly();

    final int notificationId = id.hashCode & 0x7fffffff;
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      await showAdminNotification(id: id, title: title, body: body);
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      title.trim().isEmpty ? 'Daily Kharcha' : title.trim(),
      body.trim().isEmpty ? 'New notification received' : body.trim(),
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_kharcha_admin_alerts',
          'Daily Kharcha Alerts',
          channelDescription: 'Admin updates and important app alerts',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: id,
    );
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    await initLocalOnly();
    await cancelReminder();

    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('Reminder scheduled at: $scheduledDate');

    await _notificationsPlugin.zonedSchedule(
      1001,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_kharcha_reminder_channel',
          'Daily Kharcha Reminders',
          channelDescription: 'Daily transaction reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder() async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(1001);
  }
}
