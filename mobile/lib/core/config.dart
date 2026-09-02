/// Backend base URLs. Override at build/run time, e.g.:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api
///                --dart-define=WS_BASE_URL=http://192.168.1.20:3000
///
/// The Android emulator's host loopback is 10.0.2.2, not localhost/127.0.0.1
/// — that's the default here since Phase 1 is developed against a local
/// backend on the same machine as the emulator.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Target size for on-device photo compression before upload.
  static const int photoTargetBytes = 200 * 1024;
  static const int maxEngineAudioSeconds = 15;
}
