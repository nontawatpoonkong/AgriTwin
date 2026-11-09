import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/api_client.dart';
import 'features/dashboard/dashboard_page.dart';

class AgriTwinApp extends StatelessWidget {
  const AgriTwinApp({super.key, required this.source});

  final DashboardSource source;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriTwin',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: DashboardPage(source: source),
    );
  }
}
