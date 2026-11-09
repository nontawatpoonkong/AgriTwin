import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/api_client.dart';

void main() {
  runApp(AgriTwinApp(source: AgriTwinApi(baseUrl: AppConfig.apiBaseUrl)));
}
