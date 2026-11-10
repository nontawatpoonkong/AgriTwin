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

/// Line chart of one sensor's readings (oldest first, at least one). Suspect values get a marker.
/// Drawn with a CustomPainter so the app needs no chart package (AGENTS.md rule 9).
class HistoryChart extends StatelessWidget {
  const HistoryChart({super.key, required this.readings, required this.decimals});

  final List<LatestReading> readings;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = readings.map((r) => r.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    return Semantics(
      label: 'กราฟ ${readings.length} ค่า ต่ำสุด ${low.toStringAsFixed(decimals)} '
          'สูงสุด ${high.toStringAsFixed(decimals)}',
      child: SizedBox(
        height: AppTokens.chartHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _HistoryChartPainter(
            segments: splitAtGaps(readings),
            low: low,
            high: high,
            decimals: decimals,
            lineColor: theme.colorScheme.primary,
            gridColor: theme.colorScheme.outlineVariant,
            labelStyle: theme.textTheme.bodySmall ?? const TextStyle(fontSize: AppTokens.captionFontSize),
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
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<List<LatestReading>> segments;
  final double low;
  final double high;
  final int decimals;
  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final first = segments.first.first.measuredAt;
    final last = segments.last.last.measuredAt;
    final startLabel = _label(formatDayTime(first));
    final endLabel = _label(formatDayTime(last));
    final plot = Rect.fromLTRB(
      AppTokens.chartLabelWidth,
      AppTokens.space2,
      size.width - AppTokens.space1,
      size.height - startLabel.height - AppTokens.space2,
    );

    // Leave room above and below the data; a flat series gets a band so it sits mid-chart.
    final spread = high - low;
    final pad = spread == 0 ? math.max(high.abs() * 0.05, 1.0) : spread * 0.1;
    final bottom = low - pad;
    final top = high + pad;
    double yOf(double v) => plot.bottom - (v - bottom) / (top - bottom) * plot.height;

    final span = last.difference(first).inMilliseconds;
    double xOf(DateTime t) =>
        span == 0 ? plot.center.dx : plot.left + t.difference(first).inMilliseconds / span * plot.width;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = AppTokens.chartGridLineWidth;
    for (final v in {low, (low + high) / 2, high}) {
      final y = yOf(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = _label(v.toStringAsFixed(decimals));
      label.paint(canvas, Offset(plot.left - label.width - AppTokens.space1, y - label.height / 2));
    }

    final line = Paint()
      ..color = lineColor
      ..strokeWidth = AppTokens.chartLineWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = lineColor;
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
      canvas.drawPath(path, line);
    }

    final suspect = Paint()..color = AppTokens.suspect;
    for (final r in segments.expand((s) => s).where((r) => r.isSuspect)) {
      canvas.drawCircle(Offset(xOf(r.measuredAt), yOf(r.value)), AppTokens.chartPointRadius, suspect);
    }

    startLabel.paint(canvas, Offset(plot.left, plot.bottom + AppTokens.space1));
    if (span > 0) {
      endLabel.paint(canvas, Offset(plot.right - endLabel.width, plot.bottom + AppTokens.space1));
    }
  }

  TextPainter _label(String text) =>
      TextPainter(text: TextSpan(text: text, style: labelStyle), textDirection: TextDirection.ltr)..layout();

  @override
  bool shouldRepaint(_HistoryChartPainter old) =>
      old.segments != segments ||
      old.low != low ||
      old.high != high ||
      old.decimals != decimals ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.labelStyle != labelStyle;
}
