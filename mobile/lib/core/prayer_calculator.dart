import 'dart:math' as math;

import 'methods.dart';

enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerX on Prayer {
  bool get isObligatory => this != Prayer.sunrise;
  String get nameAr => const ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'][index];
}

/// Times of one local calendar day. Instants are UTC; convert for display with the location's zone.
class DailyTimes {
  final DateTime date; // local calendar date (y/m/d only)
  final Map<Prayer, DateTime> utc;
  const DailyTimes(this.date, this.utc);
  DateTime operator [](Prayer p) => utc[p]!;
}

class CalculationOptions {
  final CalculationMethod method;
  final AsrMadhab madhab;
  final HighLatitudeRule highLatitude;
  const CalculationOptions(this.method, {this.madhab = AsrMadhab.shafii, this.highLatitude = HighLatitudeRule.angleBased});
}

/// Offline astronomical engine — a line-by-line port of the desktop app's tested C# engine
/// (USNO solar position equations, 3 refinement iterations, rounding to the nearest minute).
class PrayerCalculator {
  static const _iterations = 3;

  /// [isRamadan] lets Umm al-Qura use 120 min Isha during Ramadan.
  static DailyTimes calculate(int year, int month, int day, double lat, double lng, CalculationOptions opt,
      {bool isRamadan = false}) {
    final jDate = julianDate(year, month, day) - lng / (15.0 * 24.0);
    double fajr = 5, sunrise = 6, dhuhr = 12, asr = 13, sunset = 18, maghrib = 18, isha = 18;
    const riseSet = 0.833;
    final m = opt.method;
    final asrFactor = opt.madhab == AsrMadhab.hanafi ? 2 : 1;

    for (var i = 0; i < _iterations; i++) {
      fajr = _sunAngleTime(jDate, m.fajrAngle, _p(fajr, 5), lat, true);
      sunrise = _sunAngleTime(jDate, riseSet, _p(sunrise, 6), lat, true);
      dhuhr = _midDay(jDate, _p(dhuhr, 12));
      asr = _asrTime(jDate, asrFactor, _p(asr, 13), lat);
      sunset = _sunAngleTime(jDate, riseSet, _p(sunset, 18), lat, false);
      maghrib = m.maghribAngle != null ? _sunAngleTime(jDate, m.maghribAngle!, _p(maghrib, 18), lat, false) : sunset;
      if (m.ishaAngle != null) isha = _sunAngleTime(jDate, m.ishaAngle!, _p(isha, 18), lat, false);
    }

    if (m.maghribAngle == null) maghrib = sunset + m.maghribMinutes / 60.0;
    if (m.ishaMinutes != null) {
      final minutes = (isRamadan && m.ishaMinutesInRamadan != null) ? m.ishaMinutesInRamadan! : m.ishaMinutes!;
      isha = maghrib + minutes / 60.0;
    }

    if (opt.highLatitude != HighLatitudeRule.none && !sunrise.isNaN && !sunset.isNaN) {
      final night = _timeDiff(sunset, sunrise);
      fajr = _adjustHighLat(fajr, sunrise, m.fajrAngle, night, opt.highLatitude, true);
      if (m.ishaAngle != null) isha = _adjustHighLat(isha, sunset, m.ishaAngle!, night, opt.highLatitude, false);
      if (m.maghribAngle != null) maghrib = _adjustHighLat(maghrib, sunset, m.maghribAngle!, night, opt.highLatitude, false);
    }

    final shift = -lng / 15.0;
    final midnight = DateTime.utc(year, month, day);
    DateTime toInstant(double h) {
      if (h.isNaN) throw StateError('Prayer time undefined for this location/date');
      final minutes = ((h + shift) * 60.0).roundHalfAwayFromZero();
      return midnight.add(Duration(minutes: minutes));
    }

    return DailyTimes(DateTime(year, month, day), {
      Prayer.fajr: toInstant(fajr),
      Prayer.sunrise: toInstant(sunrise),
      Prayer.dhuhr: toInstant(dhuhr),
      Prayer.asr: toInstant(asr),
      Prayer.maghrib: toInstant(maghrib),
      Prayer.isha: toInstant(isha),
    });
  }

  static double julianDate(int year, int month, int day) {
    if (month <= 2) { year -= 1; month += 12; }
    final a = (year / 100.0).floorToDouble();
    final b = 2 - a + (a / 4.0).floorToDouble();
    return (365.25 * (year + 4716)).floorToDouble() + (30.6001 * (month + 1)).floorToDouble() + day + b - 1524.5;
  }

  static (double, double) sunPosition(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * _dSin(g) + 0.020 * _dSin(2 * g));
    final e = 23.439 - 0.00000036 * d;
    final ra = _dArcTan2(_dCos(e) * _dSin(l), _dCos(l)) / 15.0;
    final eqt = q / 15.0 - _fixHour(ra);
    final decl = _dArcSin(_dSin(e) * _dSin(l));
    return (decl, eqt);
  }

  static double _midDay(double jDate, double t) => _fixHour(12 - sunPosition(jDate + t).$2);

  static double _sunAngleTime(double jDate, double angle, double t, double lat, bool ccw) {
    final decl = sunPosition(jDate + t).$1;
    final noon = _midDay(jDate, t);
    final cosH = (-_dSin(angle) - _dSin(decl) * _dSin(lat)) / (_dCos(decl) * _dCos(lat));
    if (cosH < -1 || cosH > 1) return double.nan;
    final h = _dArcCos(cosH) / 15.0;
    return noon + (ccw ? -h : h);
  }

  static double _asrTime(double jDate, int factor, double t, double lat) {
    final decl = sunPosition(jDate + t).$1;
    final angle = -_dArcCot(factor + _dTan((lat - decl).abs()));
    return _sunAngleTime(jDate, angle, t, lat, false);
  }

  static double _adjustHighLat(double time, double base, double angle, double night, HighLatitudeRule rule, bool ccw) {
    final portion = switch (rule) {
          HighLatitudeRule.angleBased => angle / 60.0,
          HighLatitudeRule.oneSeventh => 1.0 / 7.0,
          HighLatitudeRule.middleOfNight => 0.5,
          HighLatitudeRule.none => 1.0,
        } * night;
    final diff = ccw ? _timeDiff(time, base) : _timeDiff(base, time);
    if (time.isNaN || diff > portion) return base + (ccw ? -portion : portion);
    return time;
  }

  static double _p(double hours, double fallback) => (hours.isNaN ? fallback : hours) / 24.0;
  static double _timeDiff(double t1, double t2) => _fixHour(t2 - t1);
  static double _rad(double d) => d * math.pi / 180.0;
  static double _deg(double r) => r * 180.0 / math.pi;
  static double _dSin(double d) => math.sin(_rad(d));
  static double _dCos(double d) => math.cos(_rad(d));
  static double _dTan(double d) => math.tan(_rad(d));
  static double _dArcSin(double x) => _deg(math.asin(x));
  static double _dArcCos(double x) => _deg(math.acos(x));
  static double _dArcTan2(double y, double x) => _deg(math.atan2(y, x));
  static double _dArcCot(double x) => _deg(math.atan(1.0 / x));
  static double _fixAngle(double a) => _fix(a, 360);
  static double _fixHour(double a) => _fix(a, 24);
  static double _fix(double a, double b) {
    a -= b * (a / b).floorToDouble();
    return a < 0 ? a + b : a;
  }
}

extension on double {
  int roundHalfAwayFromZero() => this < 0 ? -((-this) + 0.5).floor() : (this + 0.5).floor();
}
