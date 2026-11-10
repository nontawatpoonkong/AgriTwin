import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/api_client.dart';
import 'features/dashboard/dashboard_page.dart';

class AgriTwinApp extends StatelessWidget {
  const AgriTwinApp({super.key, required this.source, this.historySource});

  final DashboardSource source;
  final HistorySource? historySource;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriTwin',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: DashboardPage(source: source, historySource: historySource),
    );
  }
}
