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
