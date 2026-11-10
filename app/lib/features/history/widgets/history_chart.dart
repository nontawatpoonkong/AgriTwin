import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models.dart';

/// A gap shorter than this never breaks the line, however regular the readings are.
const Duration _minimumGap = Duration(minutes: 5);

/// Splits readings (oldest first) wherever two readings are much further apart than usual, so the
/// chart does not draw a straight line across missing data.
List<List<LatestReading>> splitAtGaps(List<LatestReading> readings) {
  if (readings.length < 2) return [if (readings.isNotEmpty) readings];
  final steps = [
    for (var i = 1; i < readings.length; i++)
      readings[i].measuredAt.difference(readings[i - 1].measuredAt),
  ]..sort();
  final typical = steps[steps.length ~/ 2] * 5;
  final gap = typical > _minimumGap ? typical : _minimumGap;
  final segments = <List<LatestReading>>[
    [readings.first],
  ];
  for (var i = 1; i < readings.length; i++) {
    if (readings[i].measuredAt.difference(readings[i - 1].measuredAt) > gap) segments.add([]);
    segments.last.add(readings[i]);
  }
  return segments;
}

/// Area chart of one sensor's readings (oldest first, at least one), in the style of the design's
/// sensor chart. Suspect values get a marker, the newest reading a ring, and gaps break the line.
/// [compact] drops the value axis for the dashboard trend card.
/// Drawn with a CustomPainter so the app needs no chart package (AGENTS.md rule 9).
class HistoryChart extends StatelessWidget {
  const HistoryChart({super.key, required this.readings, required this.decimals, this.compact = false});

  final List<LatestReading> readings;
  final int decimals;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final values = readings.map((r) => r.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    return Semantics(
      label: 'กราฟ ${readings.length} ค่า ต่ำสุด ${low.toStringAsFixed(decimals)} '
          'สูงสุด ${high.toStringAsFixed(decimals)}',
      child: SizedBox(
        height: compact ? AppTokens.trendChartHeight : AppTokens.chartHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _HistoryChartPainter(
            segments: splitAtGaps(readings),
            low: low,
            high: high,
            decimals: decimals,
            compact: compact,
          ),
        ),
      ),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  _HistoryChartPainter({
    required this.segments,
    required this.low,
    required this.high,
    required this.decimals,
    required this.compact,
  });

  final List<List<LatestReading>> segments;
  final double low;
  final double high;
  final int decimals;
  final bool compact;

  static const _axisStyle = TextStyle(fontSize: AppTokens.fontAxis, color: AppTokens.textMuted);
  static const _timeStyle = TextStyle(fontSize: AppTokens.fontAxis, color: AppTokens.textSecondary);

  @override
  void paint(Canvas canvas, Size size) {
    final first = segments.first.first.measuredAt;
    final last = segments.last.last.measuredAt;
    final span = last.difference(first).inMilliseconds;
    // Up to a day and a half reads best as clock times; longer ranges as dates.
    final timeLabel = span <= const Duration(hours: 36).inMilliseconds ? formatHourMinute : formatDayMonth;
    final labelHeight = _label('0', _timeStyle).height;
    const ring = AppTokens.chartEndRingRadius;
    final plot = Rect.fromLTRB(
      compact ? ring : AppTokens.chartLabelWidth,
      AppTokens.space2,
      size.width - ring - 1,
      size.height - labelHeight - AppTokens.space1,
    );

    // Leave room above and below the data; a flat series gets a band so it sits mid-chart.
    final spread = high - low;
    final pad = spread == 0 ? math.max(high.abs() * 0.05, 1.0) : spread * 0.12;
    final bottom = low - pad;
    final top = high + pad;
    double yOf(double v) => plot.bottom - (v - bottom) / (top - bottom) * plot.height;
    double xOf(DateTime t) =>
        span == 0 ? plot.center.dx : plot.left + t.difference(first).inMilliseconds / span * plot.width;

    if (!compact) {
      final grid = Paint()
        ..color = AppTokens.border
        ..strokeWidth = AppTokens.chartGridLineWidth;
      for (final v in {low, (low + high) / 2, high}) {
        final y = yOf(v);
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
        final label = _label(v.toStringAsFixed(decimals), _axisStyle);
        label.paint(canvas, Offset(plot.left - label.width - AppTokens.space2, y - label.height / 2));
      }
    }

    final fill = Paint()..color = AppTokens.chartFill;
    final line = Paint()
      ..color = AppTokens.primary
      ..strokeWidth = AppTokens.chartLineWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = AppTokens.primary;
    for (final segment in segments) {
      if (segment.length == 1) {
        final r = segment.single;
        canvas.drawCircle(Offset(xOf(r.measuredAt), yOf(r.value)), AppTokens.chartPointRadius, dot);
        continue;
      }
      final path = Path()..moveTo(xOf(segment.first.measuredAt), yOf(segment.first.value));
      for (final r in segment.skip(1)) {
        path.lineTo(xOf(r.measuredAt), yOf(r.value));
      }
      final area = Path.from(path)
        ..lineTo(xOf(segment.last.measuredAt), plot.bottom)
        ..lineTo(xOf(segment.first.measuredAt), plot.bottom)
        ..close();
      canvas.drawPath(area, fill);
      canvas.drawPath(path, line);
    }

    final suspect = Paint()..color = AppTokens.suspect;
    for (final r in segments.expand((s) => s).where((r) => r.isSuspect)) {
      canvas.drawCircle(Offset(xOf(r.measuredAt), yOf(r.value)), AppTokens.chartPointRadius, suspect);
    }

    // Ring on the newest reading, as in the design.
    final newest = segments.last.last;
    final ringCenter = Offset(xOf(newest.measuredAt), yOf(newest.value));
    canvas.drawCircle(ringCenter, ring, Paint()..color = AppTokens.surface);
    canvas.drawCircle(
      ringCenter,
      ring,
      Paint()
        ..color = AppTokens.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppTokens.chartLineWidth,
    );

    // Time labels: start, middle and end of the data (one label when there is a single time).
    final fractions = span == 0 ? const [0.5] : const [0.0, 0.5, 1.0];
    for (final f in fractions) {
      final t = first.add(Duration(milliseconds: (span * f).round()));
      final label = _label(timeLabel(t), _timeStyle);
      final x = plot.left + f * plot.width;
      final dx = f == 0 ? x : (f == 1 ? x - label.width : x - label.width / 2);
      label.paint(canvas, Offset(dx.clamp(0, size.width - label.width), plot.bottom + AppTokens.space1));
    }
  }

  TextPainter _label(String text, TextStyle style) =>
      TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();

  @override
  bool shouldRepaint(_HistoryChartPainter old) =>
      old.segments != segments ||
      old.low != low ||
      old.high != high ||
      old.decimals != decimals ||
      old.compact != compact;
}
