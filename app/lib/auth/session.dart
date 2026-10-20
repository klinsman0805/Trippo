import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Who the app is, to the server.
///
/// An anonymous Supabase user, made on first launch and kept on the device:
/// the first trip needs no account, and every trip still belongs to someone.
/// Signing in properly later links an identity to this same user, so nothing
/// made before then is lost.
/// What offering an email address turned out to mean.
enum EmailLink {
  /// Nobody holds it. A code was sent; confirming keeps this user and gives
  /// them a way back in — the trips made so far are untouched.
  linking,

  /// Somebody does, and it is almost always this person on another device.
  /// A code was sent; confirming signs in as that account, which leaves the
  /// user this device has been planning as behind.
  signingIn,
}

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

  /// The address this user signs in with, or null while they are anonymous.
  String? get email {
    final address = _auth.currentUser?.email;
    return address == null || address.isEmpty ? null : address;
  }

  /// No account yet — everything made so far lives and dies on this device.
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  /// Offer an address, and find out which of the two things that means.
  ///
  /// Either way a six-digit code is sent and [confirmEmail] finishes the job.
  /// Codes rather than links on purpose: a link has to come back into the app
  /// through a URL scheme and a universal-link entitlement, which is a lot of
  /// moving parts to get somebody their own trips back.
  Future<EmailLink> offerEmail(String address) async {
    try {
      await _auth.updateUser(UserAttributes(email: address));
      return EmailLink.linking;
    } on AuthException catch (error) {
      if (!_alreadyTaken(error)) rethrow;
      // Taken, so it cannot be linked to this user — but the person in front
      // of us is almost certainly its owner, arriving on a second device.
      // Signing them in is the useful answer; what this device planned in the
      // meantime is carried across afterwards, deliberately.
      await _auth.signInWithOtp(email: address);
      return EmailLink.signingIn;
    }
  }

  /// Finish what [offerEmail] started.
  ///
  /// Returns the access token of the user being left behind, and null when
  /// nobody is. It is the only proof that device's trips were ever theirs, so
  /// it is read *before* the code is verified — after that the session
  /// belongs to someone else.
  Future<String?> confirmEmail({
    required String address,
    required String code,
    required EmailLink mode,
  }) async {
    if (mode == EmailLink.linking) {
      // The same user throughout: the id is kept, so every trip stays owned
      // by the row that already owns it and nothing has to move.
      await _auth.verifyOTP(email: address, token: code, type: OtpType.emailChange);
      return null;
    }

    final leaving = _auth.currentSession?.accessToken;
    await _auth.verifyOTP(email: address, token: code, type: OtpType.email);
    return leaving;
  }

  /// Supabase refuses a second user on one address, which is the signal that
  /// this is a sign-in rather than a sign-up. Anything else is a real failure
  /// and is left to the caller to show.
  static bool _alreadyTaken(AuthException error) =>
      error.code == 'email_exists' || error.code == 'user_already_exists';

  Future<void> _ensureSignedIn() {
    if (_auth.currentSession != null) return Future.value();
    return _signingIn ??= _auth
        .signInAnonymously()
        .then<void>((_) {})
        .whenComplete(() => _signingIn = null);
  }
}
