import 'package:flutter/foundation.dart';

/// Where the backend lives.
///
/// Override at build time:
///   flutter run --dart-define=TRIPPO_API_BASE=https://api.example.com
///
/// The default handles the awkward emulator case: the Android emulator reaches
/// the host machine at 10.0.2.2, while the iOS simulator, desktop and web all
/// share the host's localhost.
class AppConfig {
  /// The Supabase project the app signs in with, and its publishable key
  /// (safe to ship: it identifies the project, it grants nothing on its own).
  /// Both empty runs the app without sign-in, against a local server.
  ///
  ///   --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co
  ///   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

  static bool get signsIn => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  static const String _override =
      String.fromEnvironment('TRIPPO_API_BASE', defaultValue: '');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
