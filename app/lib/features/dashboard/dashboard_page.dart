import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/stale_banner.dart';
import '../../core/widgets/ui_parts.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../history/history_page.dart';
import 'dashboard_controller.dart';
import 'widgets/device_card.dart';
import 'widgets/status_hero.dart';
import 'widgets/trend_card.dart';

/// Home screen, laid out like the design's "Home Dashboard": app header, greeting, a summary card,
/// a 24-hour trend card and the latest value of every sensor per device. Only data the system has
/// is shown; the design's weather, farm selector, notifications and AI card are not built yet.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.source,
    this.historySource,
    this.pollInterval = AppConfig.pollInterval,
    this.clock,
  });

  final DashboardSource source;

  /// Enables the trend card and tapping a sensor card to open its chart (APP-1).
  final HistorySource? historySource;
  final Duration pollInterval;

  /// "Now" for the greeting before the first response; tests pass a fixed clock.
  final DateTime Function()? clock;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;
  int _trendReload = 0;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(widget.source, pollInterval: widget.pollInterval)..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    setState(() => _trendReload++);
    return _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTokens.screenPadding,
                AppTokens.space2,
                AppTokens.screenPadding,
                AppTokens.space6,
              ),
              children: [
                _Header(onRefresh: _refresh),
                const SizedBox(height: AppTokens.space4),
                _Greeting(now: _controller.data?.serverTime ?? (widget.clock ?? DateTime.now)()),
                const SizedBox(height: AppTokens.space3),
                ..._content(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final data = _controller.data;
    final error = _controller.error;

    if (data == null) {
      if (error != null) return [_ErrorView(message: error, onRetry: _controller.refresh)];
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppTokens.space6 * 2),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final trend = _trendTarget(data);
    return [
      if (error != null) StaleBanner(error: error, lastSuccessAt: _controller.lastSuccessAt),
      if (data.devices.isEmpty)
        const _EmptyView()
      else ...[
        StatusHero(data: data),
        if (widget.historySource != null && trend != null) ...[
          const SizedBox(height: AppTokens.space3),
          TrendCard(
            // Keyed so the list keeps this card's state (and its loaded chart) when the stale banner
            // is inserted above it; without a key a failed poll would rebuild it and reload the chart.
            key: const ValueKey('trend-card'),
            source: widget.historySource!,
            device: trend.$1,
            sensorType: trend.$2,
            reloadToken: _trendReload,
            clock: widget.clock,
            onOpen: () => _openHistory(trend.$1, trend.$2),
          ),
        ],
        const SizedBox(height: AppTokens.space4),
        SectionHeader(
          title: 'เซนเซอร์ล่าสุด',
          hint: widget.historySource == null ? null : 'แตะการ์ดเพื่อดูกราฟ',
        ),
        const SizedBox(height: AppTokens.space2),
        ...data.devices.map(
          (d) => DeviceCard(
            device: d,
            serverTime: data.serverTime,
            onOpenHistory: widget.historySource == null ? null : (r) => _openHistory(d, r.sensorType),
          ),
        ),
      ],
    ];
  }

  /// Device and sensor for the trend card: soil moisture of the first device that reports it,
  /// otherwise the first sensor of the first device with readings.
  (DeviceLatest, String)? _trendTarget(DashboardLatest data) {
    for (final d in data.devices) {
      if (d.readings.any((r) => r.sensorType == 'soil_moisture')) return (d, 'soil_moisture');
    }
    for (final d in data.devices) {
      if (d.readings.isNotEmpty) return (d, d.readings.first.sensorType);
    }
    return null;
  }

  void _openHistory(DeviceLatest device, String sensorType) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SensorHistoryPage(
          source: widget.historySource!,
          deviceId: device.deviceId,
          deviceTitle: device.title,
          sensorType: sensorType,
          initialDevice: device,
          clock: widget.clock,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppTokens.logoSize,
          height: AppTokens.logoSize,
          decoration: BoxDecoration(
            color: AppTokens.primary,
            borderRadius: BorderRadius.circular(AppTokens.radiusLogo),
          ),
          child: const Icon(Icons.eco_outlined, size: 22, color: AppTokens.onPrimary),
        ),
        const SizedBox(width: AppTokens.space3),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AgriTwin',
                style: TextStyle(
                  fontSize: AppTokens.fontAppName,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppTokens.textPrimary,
                ),
              ),
              Text(
                'SMART FARM · DIGITAL TWIN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTokens.fontOverline,
                  fontWeight: FontWeight.w600,
                  letterSpacing: AppTokens.overlineTracking,
                  color: AppTokens.primary,
                ),
              ),
            ],
          ),
        ),
        SizedBox.square(
          dimension: AppTokens.logoSize,
          child: Material(
            color: AppTokens.surface,
            shape: const CircleBorder(side: BorderSide(color: AppTokens.border)),
            child: IconButton(
              tooltip: 'รีเฟรช',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.refresh, size: 20, color: AppTokens.textPrimary),
              onPressed: onRefresh,
            ),
          ),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(thaiGreeting(now), style: theme.textTheme.titleLarge),
        Text('ภาพรวมฟาร์มวันนี้ · ${formatThaiDay(now)}', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space6 * 2),
      child: Column(
        children: [
          const Icon(Icons.sensors_off, size: 48, color: AppTokens.textMuted),
          const SizedBox(height: AppTokens.space3),
          Text('ยังไม่มีข้อมูลจากอุปกรณ์', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.space2),
          Text(
            'ลองรัน simulator: python simulator/simulate.py',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space6),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppTokens.error),
          const SizedBox(height: AppTokens.space3),
          // The short reason only; the technical detail is in the log (AgriTwinApi).
          Text(message, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTokens.space2),
          Text(
            'ยังโหลดข้อมูลไม่ได้ ตรวจว่าเซิร์ฟเวอร์เปิดอยู่ แล้วกดลองใหม่',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppTokens.space1),
          // The address the app calls, so a wrong API_BASE_URL is easy to spot when testing.
          Text('เซิร์ฟเวอร์: ${AppConfig.apiBaseUrl}', textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppTokens.space4),
          FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
