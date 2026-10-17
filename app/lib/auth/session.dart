import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Who the app is, to the server.
///
/// An anonymous Supabase user, made on first launch and kept on the device:
/// the first trip needs no account, and every trip still belongs to someone.
/// Signing in properly later links an identity to this same user, so nothing
/// made before then is lost.
class AppSession {
  AppSession._(this._auth);

  /// A session over a given auth client — for tests, which cannot reach
  /// Supabase.
  @visibleForTesting
  factory AppSession.withAuth(GoTrueClient auth) => AppSession._(auth);

  final GoTrueClient _auth;

  /// One sign-in at a time. On first launch several requests can ask for a
  /// token at once, and each starting its own anonymous sign-in would make a
  /// new user per request — with the trip landing on whichever won.
  Future<void>? _signingIn;

  /// Null when the app is built without Supabase, which means running against
  /// a local server that does not ask who you are.
  ///
  /// Never throws for want of a network: a first launch offline still opens
  /// the app, and the sign-in is tried again with the first request.
  static Future<AppSession?> start() async {
    if (!AppConfig.signsIn) return null;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
    final session = AppSession._(Supabase.instance.client.auth);
    try {
      await session._ensureSignedIn();
    } on Exception {
      // Retried by [accessToken].
    }
    return session;
  }

  /// The current access token, signing in or refreshing first if needed.
  Future<String?> accessToken() async {
    try {
      await _ensureSignedIn();
      final session = _auth.currentSession;
      if (session != null && session.isExpired) await refresh();
    } on Exception {
      // The request goes without, the server answers 401, and the caller
      // shows that as it shows any failed request.
    }
    return _auth.currentSession?.accessToken;
  }

  /// A fresh token, after the server turned one away.
  Future<void> refresh() async {
    try {
      await _auth.refreshSession();
    } on AuthException {
      // A refresh token can itself be revoked or expired; start over as a new
      // anonymous user rather than leave the app unable to sign in at all.
      await _auth.signOut();
      await _ensureSignedIn();
    }
  }

  Future<void> _ensureSignedIn() {
    if (_auth.currentSession != null) return Future.value();
    return _signingIn ??= _auth
        .signInAnonymously()
        .then<void>((_) {})
        .whenComplete(() => _signingIn = null);
  }
}
