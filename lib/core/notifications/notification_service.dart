
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int _dailyReminderId = 200;
  static const String _enabledKey = 'daily_reminder_enabled';
  static const String _hourKey = 'daily_reminder_hour';
  static const String _minuteKey = 'daily_reminder_minute';

  
Future<void> showBudgetAlert({
  required int id,
  required String title,
  required String body,
}) async {
  await initialize();

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'expense_manager_budget_alerts',
      'Budget Alerts',
      channelDescription: 'Alerts when spending reaches budget limits',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  await _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
  );
}


  Future<void> initialize() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings: settings);

    tz.initializeTimeZones();

    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> showTestNotification() async {
    await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'expense_manager_general',
        'Expense Manager',
        channelDescription: 'Expense Manager reminders and alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: 100,
      title: 'Expense Manager',
      body: 'Your notifications are working successfully!',
      notificationDetails: details,
    );
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();

    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'expense_manager_daily_reminder',
        'Daily Expense Reminder',
        channelDescription: 'Daily reminders to record expenses',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.cancel(id: _dailyReminderId);

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'Time to review your finances',
      body: 'Record today’s income and expenses in Expense Manager.',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    await prefs.setBool(_enabledKey, true);
  }

  Future<void> cancelDailyReminder() async {
    await initialize();

    await _plugin.cancel(id: _dailyReminderId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<bool> isDailyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<int> getReminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hourKey) ?? 21;
  }

  Future<int> getReminderMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_minuteKey) ?? 0;
  }
}
