import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/api_client.dart';

void main() {
  final api = AgriTwinApi(baseUrl: AppConfig.apiBaseUrl);
  runApp(AgriTwinApp(source: api, historySource: api));
}
