// منبهات الصلاة: تُحفظ إعدادات كل صلاة، وتُجدول التنبيهات للأيام السبعة القادمة
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_times.dart';

/// الصلوات التي يمكن ضبط منبه لها
const List<String> kAlarmable = [
  'fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha', 'midnight', 'lastThird',
];

/// خيارات المنبه: -1 = إيقاف، 0 = عند الأذان، وغيرها = دقائق قبل الأذان
const List<int> kAlarmOptions = [0, 5, 10, 15];

class Alarms {
  Alarms._();
  static final Alarms instance = Alarms._();

  final _plugin = FlutterLocalNotificationsPlugin();
  late tz.Location _kuwait;
  final Map<String, int> _settings = {};
  bool _ready = false;

  static const _days = 7;
  static const _channel = AndroidNotificationDetails(
    'prayer_alarms',
    'منبهات الصلاة',
    channelDescription: 'تنبيه بدخول وقت الصلاة',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _kuwait = tz.getLocation('Asia/Kuwait');
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    final prefs = await SharedPreferences.getInstance();
    for (final k in kAlarmable) {
      _settings[k] = prefs.getInt('alarm_$k') ?? -1;
    }
    _ready = true;
    await reschedule();
  }

  /// -1 إيقاف، 0 عند الأذان، أو عدد الدقائق قبله
  int settingFor(String prayer) => _settings[prayer] ?? -1;
  bool isOn(String prayer) => settingFor(prayer) >= 0;

  Future<bool> set(String prayer, int value) async {
    var allowed = true;
    if (value >= 0) allowed = await _askPermission();
    _settings[prayer] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alarm_$prayer', value);
    await reschedule();
    return allowed;
  }

  Future<bool> _askPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  /// يمسح كل التنبيهات ويجدولها من جديد للأيام القادمة
  Future<void> reschedule() async {
    if (!_ready) return;
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(_kuwait);
    final today = DateTime.utc(now.year, now.month, now.day);
    var id = 0;

    Future<void> add(String k, DateTime day, num minutes, int before) async {
      final at = tz.TZDateTime(_kuwait, day.year, day.month, day.day)
          .add(Duration(seconds: ((minutes - before) * 60).round()));
      if (!at.isAfter(now)) return;
      final name = kNames[k]!;
      final mins = minutesLabel(before);
      final String title;
      if (k == 'sunrise') {
        title = before == 0 ? 'الشروق الآن' : 'باقي $mins على الشروق';
      } else if (k == 'midnight') {
        title = before == 0 ? 'منتصف الليل الآن' : 'باقي $mins على منتصف الليل';
      } else if (k == 'lastThird') {
        title = before == 0 ? 'دخل الثلث الأخير من الليل' : 'باقي $mins على الثلث الأخير';
      } else {
        title = before == 0 ? 'حان وقت صلاة $name' : 'باقي $mins على أذان $name';
      }
      final f = formatMinutes(minutes);
      final body = 'مواقيت الجهراء • $name ${f.hm} ${f.period}';
      try {
        await _plugin.zonedSchedule(
          id++,
          title,
          body,
          at,
          const NotificationDetails(
            android: _channel,
            iOS: DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // إذا رفض النظام الجدولة الدقيقة نستخدم التقريبية
        await _plugin.zonedSchedule(
          id++,
          title,
          body,
          at,
          const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    // نبدأ من أمس عشان الثلث الأخير من الليلة الحالية إذا كان بعد منتصف الليل
    for (var d = -1; d < _days; d++) {
      final day = today.add(Duration(days: d));
      if (d >= 0) {
        final t = prayerTimesFor(day);
        for (final k in kAlarmable) {
          if (kNightKeys.contains(k)) continue;
          final before = settingFor(k);
          if (before >= 0) await add(k, day, t[k]!, before);
        }
      }
      final n = nightStarting(day);
      for (final k in kNightKeys) {
        final before = settingFor(k);
        if (before >= 0) await add(k, day, nightValue(n, k), before);
      }
    }
  }
}

/// "5 دقائق" أو "15 دقيقة"
String minutesLabel(int m) => (m >= 3 && m <= 10) ? '$m دقائق' : '$m دقيقة';
