import 'package:agritwin_app/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// All times here are local DateTimes, so the results do not depend on the machine's time zone.
void main() {
  test('formatClockOrDay adds the date only when the time is not from today', () {
    final now = DateTime(2026, 11, 10, 9);
    expect(formatClockOrDay(DateTime(2026, 11, 10, 8, 5, 7), now), '08:05:07');
    expect(formatClockOrDay(DateTime(2026, 11, 9, 21, 43, 35), now), '9/11 21:43');
    expect(formatClockOrDay(DateTime(2025, 11, 10, 8, 5), now), '10/11 08:05'); // same day, other year
  });

  test('thaiGreeting follows the time of day', () {
    expect(thaiGreeting(DateTime(2026, 11, 10, 4, 59)), 'สวัสดี');
    expect(thaiGreeting(DateTime(2026, 11, 10, 5)), 'สวัสดีตอนเช้า');
    expect(thaiGreeting(DateTime(2026, 11, 10, 12)), 'สวัสดีตอนบ่าย');
    expect(thaiGreeting(DateTime(2026, 11, 10, 17)), 'สวัสดีตอนเย็น');
    expect(thaiGreeting(DateTime(2026, 11, 10, 21)), 'สวัสดี');
  });

  test('formatThaiDay gives the Thai weekday, day and short month', () {
    expect(formatThaiDay(DateTime(2026, 11, 9)), 'จันทร์ 9 พ.ย.');
    expect(formatThaiDay(DateTime(2026, 11, 15)), 'อาทิตย์ 15 พ.ย.');
  });
}
