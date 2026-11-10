/// Thai relative age, e.g. "12 วินาทีที่แล้ว".
String formatAge(Duration age) {
  final d = age.isNegative ? Duration.zero : age;
  if (d.inSeconds < 60) return '${d.inSeconds} วินาทีที่แล้ว';
  if (d.inMinutes < 60) return '${d.inMinutes} นาทีที่แล้ว';
  if (d.inHours < 24) return '${d.inHours} ชั่วโมงที่แล้ว';
  return '${d.inDays} วันที่แล้ว';
}

/// Local clock time HH:mm:ss.
String formatClock(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

/// Local day and time "d/M HH:mm", e.g. "9/11 14:05".
String formatDayTime(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.day}/${l.month} ${two(l.hour)}:${two(l.minute)}';
}

/// "HH:mm:ss" when [t] falls on the same local day as [now], otherwise "d/M HH:mm", so a time from
/// an earlier day (an offline device, data left on screen overnight) is never read as today's.
String formatClockOrDay(DateTime t, DateTime now) {
  final l = t.toLocal();
  final n = now.toLocal();
  final sameDay = l.year == n.year && l.month == n.month && l.day == n.day;
  return sameDay ? formatClock(t) : formatDayTime(t);
}

/// Local time "HH:mm".
String formatHourMinute(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}

/// Local day "d/M", e.g. "9/11".
String formatDayMonth(DateTime t) {
  final l = t.toLocal();
  return '${l.day}/${l.month}';
}

const _thaiWeekdays = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
const _thaiMonths = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', //
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// Local Thai day, e.g. "จันทร์ 9 พ.ย.".
String formatThaiDay(DateTime t) {
  final l = t.toLocal();
  return '${_thaiWeekdays[l.weekday - 1]} ${l.day} ${_thaiMonths[l.month - 1]}';
}

/// Greeting for the local hour, e.g. "สวัสดีตอนเช้า".
String thaiGreeting(DateTime t) {
  final h = t.toLocal().hour;
  if (h >= 5 && h < 12) return 'สวัสดีตอนเช้า';
  if (h >= 12 && h < 17) return 'สวัสดีตอนบ่าย';
  if (h >= 17 && h < 21) return 'สวัสดีตอนเย็น';
  return 'สวัสดี';
}
