import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _adminChannel = AndroidNotificationChannel(
    'daily_kharcha_admin_alerts',
    'Daily Kharcha Alerts',
    description: 'Admin updates and important app alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (kIsWeb) return;

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
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> showAdminNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

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
          fullScreenIntent: true,
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
