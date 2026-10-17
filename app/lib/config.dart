import 'package:flutter/foundation.dart';

/// Where the backend lives.
///
/// Override at build time:
///   flutter run --dart-define=TRIPPO_API_BASE=https://api.example.com
///
/// The default handles the awkward emulator case: the Android emulator reaches
/// the host machine at 10.0.2.2, while the iOS simulator, desktop and web all
/// share the host's localhost.
///
/// `TRIPPO_API_BASE=same-origin` is for a web build the server hosts itself:
/// the API lives at whatever address served the page, so nothing about the
/// deploy has to be known when the app is built.
class AppConfig {
  static const String _override =
      String.fromEnvironment('TRIPPO_API_BASE', defaultValue: '');

  static String get apiBaseUrl {
    if (_override == 'same-origin') return Uri.base.origin;
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
