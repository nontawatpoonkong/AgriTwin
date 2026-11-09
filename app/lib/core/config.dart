/// Build-time configuration.
///
/// Override the API address with --dart-define, e.g.
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
///   flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000   (Android emulator)
///   flutter run -d PHONE_DEVICE_ID --dart-define=API_BASE_URL=http://192.168.1.50:8000   (real phone, PC's LAN IP)
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const Duration pollInterval = Duration(seconds: 5);
}
