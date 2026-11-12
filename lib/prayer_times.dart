// حساب مواقيت الصلاة لمدينة الجهراء بطريقة الكويت
// الفجر 18°، العشاء 17.5°، العصر على المذهب الجمهوري، التوقيت +3
import 'dart:math' as math;

const double kLat = 29.3375;
const double kLng = 47.6581;
const double kTimeZone = 3;
const double kFajrAngle = 18;
const double kIshaAngle = 17.5;

/// تعديل بالدقائق لمطابقة تقويم الكويت
const Map<String, int> kAdjust = {
  'fajr': 0,
  'sunrise': 0,
  'dhuhr': 0,
  'asr': 1,
  'maghrib': 0,
  'isha': 0,
};

const List<String> kOrder = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
const List<String> kPrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
const Map<String, String> kNames = {
  'fajr': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;
double _fix(double a, double b) {
  a = a - b * (a / b).floorToDouble();
  return a < 0 ? a + b : a;
}

class _Sun {
  final double decl;
  final double eqt;
  _Sun(this.decl, this.eqt);
}

_Sun _sunPos(double jd) {
  final d = jd - 2451545.0;
  final g = _fix(357.529 + 0.98560028 * d, 360);
  final q = _fix(280.459 + 0.98564736 * d, 360);
  final l = _fix(q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)), 360);
  final e = 23.439 - 0.00000036 * d;
  final ra = _fix(
      _deg(math.atan2(math.cos(_rad(e)) * math.sin(_rad(l)), math.cos(_rad(l)))) / 15, 24);
  return _Sun(_deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l)))), q / 15 - ra);
}

double _julian(int y, int m, int d) {
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floorToDouble() +
      (30.6001 * (m + 1)).floorToDouble() +
      d +
      b -
      1524.5;
}

/// أوقات يوم واحد بالدقائق من منتصف الليل (بتوقيت الكويت)
Map<String, int> prayerTimes(int y, int m, int d) {
  final jd0 = _julian(y, m, d) - kLng / (15 * 24);
  _Sun at(double h) => _sunPos(jd0 + h / 24);
  double noon(double h) => _fix(12 - at(h).eqt, 24);
  double angleT(double angle, double h, bool ccw) {
    final s = at(h);
    final n = noon(h);
    final t = _deg(math.acos((-math.sin(_rad(angle)) -
                    math.sin(_rad(s.decl)) * math.sin(_rad(kLat))) /
                (math.cos(_rad(s.decl)) * math.cos(_rad(kLat))))) /
        15;
    return n + (ccw ? -t : t);
  }

  double asrT(double h) {
    final s = at(h);
    final a = -_deg(math.atan(1 / (1 + math.tan(_rad((kLat - s.decl).abs())))));
    return angleT(a, h, false);
  }

  var t = <String, double>{
    'fajr': 5, 'sunrise': 6, 'dhuhr': 12, 'asr': 13, 'maghrib': 18, 'isha': 18,
  };
  for (var i = 0; i < 2; i++) {
    t = {
      'fajr': angleT(kFajrAngle, t['fajr']!, true),
      'sunrise': angleT(0.833, t['sunrise']!, true),
      'dhuhr': noon(t['dhuhr']!),
      'asr': asrT(t['asr']!),
      'maghrib': angleT(0.833, t['maghrib']!, false),
      'isha': angleT(kIshaAngle, t['isha']!, false),
    };
  }
  return t.map((k, v) =>
      MapEntry(k, ((v - kLng / 15 + kTimeZone) * 60 - 0.001).ceil() + kAdjust[k]!));
}

Map<String, int> prayerTimesFor(DateTime day) => prayerTimes(day.year, day.month, day.day);

/// منتصف الليل وبداية الثلث الأخير (بالدقائق، قد تكون سالبة أو أكبر من 1440)
class NightTimes {
  final double midnight;
  final double lastThird;
  NightTimes(this.midnight, this.lastThird);
}

NightTimes nightTimes(DateTime day, {required bool beforeFajrToday}) {
  final t = prayerTimesFor(day);
  double mg, fj;
  if (beforeFajrToday) {
    mg = prayerTimesFor(day.subtract(const Duration(days: 1)))['maghrib']! - 1440.0;
    fj = t['fajr']!.toDouble();
  } else {
    mg = t['maghrib']!.toDouble();
    fj = prayerTimesFor(day.add(const Duration(days: 1)))['fajr']! + 1440.0;
  }
  final len = fj - mg;
  return NightTimes(mg + len / 2, mg + 2 * len / 3);
}

/// الوقت الحالي بتوقيت الكويت (القيم تُقرأ كما هي)
DateTime kuwaitNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// تنسيق الدقائق: الساعة والدقيقة، و"ص" أو "م"
({String hm, String period}) formatMinutes(num minutes) {
  var m = (minutes.round() % 1440 + 1440) % 1440;
  var h = m ~/ 60;
  final mm = m % 60;
  final p = h < 12 ? 'ص' : 'م';
  h = h % 12 == 0 ? 12 : h % 12;
  return (hm: '$h:${mm.toString().padLeft(2, '0')}', period: p);
}

const List<String> kGregMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
const List<String> kHijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];
/// أسماء الأيام حسب DateTime.weekday (1 = الاثنين ... 7 = الأحد)
const Map<int, String> kWeekdays = {
  1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
  5: 'الجمعة', 6: 'السبت', 7: 'الأحد',
};
/// ترتيب الأسبوع من السبت إلى الجمعة
const List<int> kWeekOrder = [6, 7, 1, 2, 3, 4, 5];

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
