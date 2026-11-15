import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import 'alarms.dart';
import 'main.dart';
import 'prayer_times.dart';

/// المدة (بالدقائق) اللي يعرض فيها التطبيق الوقت المنقضي بعد الأذان
const int kElapsedWindow = 30;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _offset = 0; // عدد الأيام عن اليوم
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = kuwaitNow();
    final today = dateOnly(now);
    final nowMin = now.hour * 60 + now.minute + now.second / 60;
    final todayTimes = prayerTimesFor(today);

    // أحداث اليوم بالترتيب: الصلوات ومنتصف الليل والثلث الأخير (من الليلة الماضية إلى فجر الغد)
    final yNight = nightStarting(today.subtract(const Duration(days: 1)));
    final tNight = nightStarting(today);
    final events = <(String, double)>[
      for (final k in kNightKeys) (k, nightValue(yNight, k) - 1440),
      for (final k in kPrayers) (k, todayTimes[k]!.toDouble()),
      for (final k in kNightKeys) (k, nightValue(tNight, k)),
      ('fajr', prayerTimesFor(today.add(const Duration(days: 1)))['fajr']! + 1440.0),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

    // الحدث القادم، والحدث اللي دخل قبل أقل من kElapsedWindow دقيقة
    final next = events.firstWhere((e) => e.$2 > nowMin);
    (String, double)? current;
    for (final e in events) {
      final d = nowMin - e.$2;
      if (d >= 0 && d < kElapsedWindow) current = e;
    }
    final int secs;
    final String label;
    if (current != null) {
      secs = ((nowMin - current.$2) * 60).floor().clamp(0, 999999).toInt();
      label = switch (current.$1) {
        'midnight' => 'مضى على منتصف الليل',
        'lastThird' => 'مضى على دخول الثلث الأخير',
        _ => 'مضى على أذان ${kNames[current.$1]}',
      };
    } else {
      secs = ((next.$2 - nowMin) * 60).ceil().clamp(0, 999999).toInt();
      label = switch (next.$1) {
        'midnight' => 'على منتصف الليل',
        'lastThird' => 'على الثلث الأخير',
        _ => 'على الأذان التالي',
      };
    }
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    final active = current ?? next;
    bool isActive(String k, num minutes) =>
        k == active.$1 && (minutes - active.$2).abs() < 1;

    // اليوم المعروض
    final shown = today.add(Duration(days: _offset));
    final isToday = _offset == 0;
    final t = prayerTimesFor(shown);
    final night = nightTimes(shown, beforeFajrToday: isToday && nowMin < t['fajr']!);

    final hijri = HijriCalendar.fromDate(DateTime(shown.year, shown.month, shown.day));
    final dateLabel =
        '${shown.day} ${kGregMonths[shown.month - 1]} - ${hijri.hDay} ${kHijriMonths[hijri.hMonth - 1]}';
    final dayName = isToday ? 'اليوم' : kWeekdays[shown.weekday]!;

    final cells = <_Cell>[
      for (final k in kOrder)
        _Cell(kNames[k]!, t[k]!, highlight: isToday && isActive(k, t[k]!), key: k),
      _Cell(kNames['midnight']!, night.midnight,
          highlight: isToday && isActive('midnight', night.midnight), key: 'midnight'),
      _Cell(kNames['lastThird']!, night.lastThird,
          highlight: isToday && isActive('lastThird', night.lastThird), key: 'lastThird'),
    ];

    return Scaffold(
      backgroundColor: AppColors.g0,
      body: Column(
        children: [
          // الرأس: المدينة والعدّاد
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.g0, AppColors.g1],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  children: [
                    const Text('الجهراء',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(label,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: current != null ? AppColors.gold : AppColors.inkDim)),
                          const SizedBox(width: 10),
                          Text('$h:${m.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontSize: 84,
                                  fontWeight: FontWeight.w400,
                                  height: 1.1,
                                  fontFeatures: [FontFeature.tabularFigures()])),
                          const SizedBox(width: 4),
                          Text(s.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontFeatures: [FontFeature.tabularFigures()])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // شريط التاريخ
          Container(
            color: AppColors.g2,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'اليوم السابق',
                  onPressed: () => setState(() => _offset--),
                  icon: const Directionality(
                      textDirection: TextDirection.ltr,
                      child: Icon(Icons.chevron_right, color: AppColors.inkDim, size: 32)),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _offset = 0),
                    child: Column(
                      children: [
                        Text(dateLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        Text(dayName,
                            style: const TextStyle(fontSize: 12, color: AppColors.inkDim)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'اليوم التالي',
                  onPressed: () => setState(() => _offset++),
                  icon: const Directionality(
                      textDirection: TextDirection.ltr,
                      child: Icon(Icons.chevron_left, color: AppColors.inkDim, size: 32)),
                ),
              ],
            ),
          ),

          // جدول الصلوات على عمودين
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
              children: [
                for (var r = 0; r < 4; r++)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _cellView(cells[r * 2], AppColors.bands[r])),
                        Container(width: 1, color: Colors.black12),
                        Expanded(child: _cellView(cells[r * 2 + 1], AppColors.bands[r])),
                      ],
                    ),
                  ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellView(_Cell c, Color bg) {
    final k = c.key;
    return _PrayerCell(
      c,
      bg,
      alarmOn: k != null && Alarms.instance.isOn(k),
      onLongPress: k == null ? null : () => _openAlarmSheet(k),
    );
  }

  Future<void> _openAlarmSheet(String k) async {
    final current = Alarms.instance.settingFor(k);
    final name = kNames[k]!;
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.g1,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  k == 'sunrise' || kNightKeys.contains(k) ? 'منبه $name' : 'منبه صلاة $name',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ),
            for (final o in kAlarmOptions)
              _option(c, o, current, o == 0 ? _atLabel(k) : 'قبل ${minutesLabel(o)}'),
            _option(c, -1, current, 'إيقاف المنبه'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    bool allowed;
    try {
      allowed = await Alarms.instance.set(k, choice);
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    setState(() {});
    final msg = choice < 0
        ? 'تم إيقاف منبه $name'
        : !allowed
            ? 'فعّل الإشعارات للتطبيق من إعدادات الجوال عشان يشتغل المنبه'
            : choice == 0
                ? 'بينبهك التطبيق عند $name كل يوم'
                : 'بينبهك التطبيق قبل $name بـ ${minutesLabel(choice)} كل يوم';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg, textAlign: TextAlign.center)));
  }

  String _atLabel(String k) => switch (k) {
        'sunrise' => 'عند الشروق',
        'midnight' || 'lastThird' => 'عند دخوله',
        _ => 'عند الأذان',
      };

  Widget _option(BuildContext c, int value, int current, String label) => ListTile(
        leading: Icon(
          value == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: value == current ? AppColors.gold : AppColors.inkDim,
        ),
        title: Text(label, style: const TextStyle(fontSize: 17)),
        onTap: () => Navigator.pop(c, value),
      );
}

class _Cell {
  final String name;
  final num minutes;
  final bool highlight;
  final bool small;
  final String? key; // مفتاح الصلاة لضبط المنبه
  _Cell(this.name, this.minutes, {this.highlight = false, this.small = false, this.key});
}

class _PrayerCell extends StatelessWidget {
  final _Cell cell;
  final Color bg;
  final bool alarmOn;
  final VoidCallback? onLongPress;
  const _PrayerCell(this.cell, this.bg, {this.alarmOn = false, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final f = formatMinutes(cell.minutes);
    final color = cell.highlight ? AppColors.hiInk : AppColors.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: Container(
      decoration: BoxDecoration(
        color: cell.highlight ? Colors.white : bg,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cell.name,
                  style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: cell.small ? FontWeight.w500 : FontWeight.w600)),
              if (alarmOn) ...[
                const SizedBox(width: 6),
                Icon(Icons.notifications_active,
                    size: 18, color: cell.highlight ? AppColors.g1 : AppColors.gold),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(f.hm,
                    style: TextStyle(
                        color: color,
                        fontSize: cell.small ? 22 : 26,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
