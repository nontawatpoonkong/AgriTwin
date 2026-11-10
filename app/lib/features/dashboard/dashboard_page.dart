import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/stale_banner.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../history/history_page.dart';
import 'dashboard_controller.dart';
import 'widgets/device_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.source,
    this.historySource,
    this.pollInterval = AppConfig.pollInterval,
  });

  final DashboardSource source;

  /// Enables tapping a sensor tile to open its history chart (APP-1).
  final HistorySource? historySource;
  final Duration pollInterval;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _controller;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriTwin'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            icon: const Icon(Icons.refresh),
            onPressed: _controller.refresh,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final data = _controller.data;
    final error = _controller.error;

    if (data == null) {
      if (error != null) {
        return _ErrorView(message: error, onRetry: _controller.refresh);
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.space4),
        children: [
          if (error != null) StaleBanner(error: error, lastSuccessAt: _controller.lastSuccessAt),
          if (data.devices.isEmpty)
            const _EmptyView()
          else
            ...data.devices.map(
              (d) => DeviceCard(
                device: d,
                serverTime: data.serverTime,
                onOpenHistory: widget.historySource == null ? null : (r) => _openHistory(d, r),
              ),
            ),
        ],
      ),
    );
  }

  void _openHistory(DeviceLatest device, LatestReading reading) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SensorHistoryPage(
          source: widget.historySource!,
          deviceId: device.deviceId,
          deviceTitle: device.title,
          sensorType: reading.sensorType,
        ),
      ),
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
          Icon(Icons.sensors_off, size: 48, color: theme.colorScheme.outline),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppTokens.space3),
            Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTokens.space2),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTokens.space1),
            Text('API: ${AppConfig.apiBaseUrl}', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTokens.space4),
            FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}
