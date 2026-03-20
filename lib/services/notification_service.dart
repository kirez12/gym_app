import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> requestPermissions() async {
    await Permission.notification.request();
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<void> showRestTimer({required int durationSeconds}) async {
    final int endTimeMs = DateTime.now().millisecondsSinceEpoch + (durationSeconds * 1000);
    final AndroidNotificationDetails liveTimerDetails = AndroidNotificationDetails(
      'live_rest_timer',
      'Rest Timer',
      channelDescription: 'Shows the live rest countdown',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: endTimeMs,
      autoCancel: false,
    );

    await flutterLocalNotificationsPlugin.show(
      0, 
      'Resting...',
      null, 
      NotificationDetails(android: liveTimerDetails),
    );

    const AndroidNotificationDetails alarmDetails = AndroidNotificationDetails(
      'rest_alarm_channel',
      'Rest Complete',
      channelDescription: 'Alerts when rest is finished',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      1, 
      'Rest Complete!',
      'Time for your next set.',
      tz.TZDateTime.now(tz.local).add(Duration(seconds: durationSeconds)),
      const NotificationDetails(android: alarmDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelRestTimer() async {
    await flutterLocalNotificationsPlugin.cancel(0); 
    await flutterLocalNotificationsPlugin.cancel(1); 
  }
}