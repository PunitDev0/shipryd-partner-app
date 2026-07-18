/// Points the app at the real shipryd-backend server. Defaults to the
/// deployed Render backend. Override at build/run time for local dev, e.g.:
///   flutter run --dart-define=API_HOST=10.0.2.2:5001 --dart-define=API_SCHEME=http   (Android emulator)
///   flutter run --dart-define=API_HOST=192.168.1.23:5001 --dart-define=API_SCHEME=http (physical device, use your LAN IP)
class ApiConfig {
  static const _host = String.fromEnvironment('API_HOST', defaultValue: 'shipryd-parcel.onrender.com');
  static const _scheme = String.fromEnvironment('API_SCHEME', defaultValue: 'https');

  static const apiBaseUrl = '$_scheme://$_host/api/v1';
  static const socketBaseUrl = '$_scheme://$_host';
}
