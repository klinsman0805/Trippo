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
  ///
  /// Which failure it was decides everything here, because retiring an
  /// anonymous user is irreversible: it has no credentials, so nobody can ever
  /// sign in as it again, and every trip it owns stays in the database under an
  /// `owner_id` no future token will carry. Unreachable, undeletable, gone.
  Future<void> refresh() async {
    try {
      await _auth.refreshSession();
    } on AuthRetryableFetchException {
      // The network failed, not the token. The session is still good — the SDK
      // keeps it in this case — so this does nothing and leaves it alone. The
      // request that asked for the refresh goes on to fail as it was already
      // going to, and the next one retries with the user intact.
      //
      // Swallowed rather than rethrown: an AuthException out of here would
      // escape ApiClient._send, which only promises ApiException, and no
      // caller would catch it. The retry answers 401 again and that path
      // reports it properly.
    } on AuthException {
      // The refresh token itself is dead — revoked, or reused and detected.
      // The SDK has already dropped the session, so there is nothing to sign
      // out of, and a new anonymous user is the only way back to an app that
      // works at all.
      //
      // It is still a one-way door, by the nature of an anonymous account: the
      // previous user's trips are now unreachable. Linking a real identity is
      // what closes it, because a linked user can always sign back in. Until
      // then this is the worst case, not a handled one.
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
