import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import 'main.dart';
import 'prayer_times.dart';

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

    // الصلاة القادمة والعدّاد (دائماً من اليوم الحالي)
    String? next;
    for (final k in kPrayers) {
      if (todayTimes[k]! > nowMin) {
        next = k;
        break;
      }
    }
    final targetMin = next != null
        ? todayTimes[next]!.toDouble()
        : prayerTimesFor(today.add(const Duration(days: 1)))['fajr']! + 1440.0;
    final secsLeft = ((targetMin - nowMin) * 60).ceil().clamp(0, 999999).toInt();
    final h = secsLeft ~/ 3600;
    final m = (secsLeft % 3600) ~/ 60;
    final s = secsLeft % 60;

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
        _Cell(kNames[k]!, t[k]!, highlight: isToday && k == next),
      _Cell('منتصف الليل', night.midnight, small: true),
      _Cell('الثلث الأخير', night.lastThird, small: true),
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
                          const Text('على الأذان التالي',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontSize: 13, color: AppColors.inkDim)),
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
                        Expanded(child: _PrayerCell(cells[r * 2], AppColors.bands[r])),
                        Container(width: 1, color: Colors.black12),
                        Expanded(child: _PrayerCell(cells[r * 2 + 1], AppColors.bands[r])),
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
}

class _Cell {
  final String name;
  final num minutes;
  final bool highlight;
  final bool small;
  _Cell(this.name, this.minutes, {this.highlight = false, this.small = false});
}

class _PrayerCell extends StatelessWidget {
  final _Cell cell;
  final Color bg;
  const _PrayerCell(this.cell, this.bg);

  @override
  Widget build(BuildContext context) {
    final f = formatMinutes(cell.minutes);
    final color = cell.highlight ? AppColors.hiInk : AppColors.ink;
    return Container(
      decoration: BoxDecoration(
        color: cell.highlight ? Colors.white : bg,
        border: const Border(top: BorderSide(color: Colors.black12)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cell.name,
              style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: cell.small ? FontWeight.w500 : FontWeight.w600)),
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
                const SizedBox(width: 4),
                Text(f.period, style: TextStyle(color: color, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
