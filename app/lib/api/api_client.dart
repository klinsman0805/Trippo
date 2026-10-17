import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Thrown for any non-2xx response, carrying the backend's error envelope
/// (`{ error: { code, message, details } }`) so callers can branch on `code`
/// rather than string-matching messages.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  /// The server is missing an API key for this capability. Callers should show
  /// the feature as unavailable rather than as a failure.
  bool get isFeatureUnavailable => statusCode == 503;

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.accessToken,
    this.refreshSession,
  }) : _client = client ?? http.Client();

  /// e.g. `http://10.0.2.2:8080` on the Android emulator, since `localhost`
  /// there refers to the emulator itself, not the host machine.
  final String baseUrl;
  final http.Client _client;

  /// The signed-in session's token, sent on every request. Null against a
  /// local server with no sign-in, which accepts requests without one.
  final Future<String?> Function()? accessToken;

  /// Called once when the server answers 401, before the request is retried:
  /// a token that expired while the app sat in the background is the usual
  /// cause, and a refresh is the whole fix.
  final Future<void> Function()? refreshSession;

  /// Planner calls run for minutes with adaptive thinking, so the default
  /// client timeout is far too aggressive for them — see [postLongRunning].
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _plannerTimeout = Duration(minutes: 8);

  static const _json = {'content-type': 'application/json'};

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/v1$path').replace(
        queryParameters: query?.isEmpty ?? true ? null : query,
      );

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async =>
      _send(
        (headers) => _client.get(_uri(path, query), headers: headers),
        timeout ?? _defaultTimeout,
      );

  /// GET a path outside the `/v1` prefix, e.g. `/health`.
  Future<Map<String, dynamic>> getUnversioned(String path) async => _send(
        (headers) => _client.get(Uri.parse('$baseUrl$path'), headers: headers),
        _defaultTimeout,
      );

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? timeout,
  }) async =>
      _send(
        (headers) => _client.post(
          _uri(path),
          headers: {...headers, ..._json},
          body: jsonEncode(body ?? const {}),
        ),
        timeout ?? _defaultTimeout,
      );

  /// For endpoints that legitimately take minutes (plan generation, imports).
  Future<Map<String, dynamic>> postLongRunning(String path, {Object? body}) =>
      post(path, body: body, timeout: _plannerTimeout);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async => _send(
        (headers) => _client.patch(
          _uri(path),
          headers: {...headers, ..._json},
          body: jsonEncode(body ?? const {}),
        ),
        _defaultTimeout,
      );

  Future<void> delete(String path) async {
    await _send(
      (headers) => _client.delete(_uri(path), headers: headers),
      _defaultTimeout,
    );
  }

  /// DELETE where the response body matters — removing an activity returns the
  /// updated plan, so the client does not have to refetch it.
  Future<Map<String, dynamic>> deleteReturning(String path) => _send(
        (headers) => _client.delete(_uri(path), headers: headers),
        _defaultTimeout,
      );

  Future<Map<String, String>> _authHeaders() async {
    final token = await accessToken?.call();
    return token == null ? const {} : {'authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
    Duration timeout, {
    bool retried = false,
  }) async {
    late http.Response response;
    try {
      response = await request(await _authHeaders()).timeout(timeout);
    } on SocketException catch (e) {
      throw ApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Could not reach the server: ${e.message}',
      );
    } on TimeoutException {
      // Every caller handles ApiException and nothing handles this, so a
      // timeout used to escape the call entirely — leaving the generating
      // screen up forever with no error and no way back.
      throw ApiException(
        statusCode: 0,
        code: 'timeout',
        message: timeout.inMinutes >= 1
            ? 'The server did not answer within '
                '${timeout.inMinutes} ${timeout.inMinutes == 1 ? 'minute' : 'minutes'}. '
                'It may still be working — reopen the trip in a moment to see.'
            : 'The server did not answer within ${timeout.inSeconds} seconds.',
      );
    }

    // Once, and only with a session to refresh: a second 401 is a real
    // refusal, and retrying it would loop.
    if (response.statusCode == 401 && !retried && refreshSession != null) {
      await refreshSession!();
      return _send(request, timeout, retried: true);
    }

    // Status is judged before the body, because a failure with an empty body
    // is common — gateway 502s, proxy 413s, an auth layer rejecting before it
    // reaches us. Returning `{}` for those would report failure as success and
    // leave the caller to crash on a field that was never going to be there.
    final failed = response.statusCode >= 400;

    // 204 No Content has no body to decode; nor does a bare error status.
    if (response.body.isEmpty) {
      if (failed) {
        throw ApiException(
          statusCode: response.statusCode,
          code: 'http_${response.statusCode}',
          message: 'The server returned ${response.statusCode} with no details.',
        );
      }
      return const {};
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        code: failed ? 'http_${response.statusCode}' : 'invalid_response',
        message: failed
            ? 'The server returned ${response.statusCode}.'
            : 'Server returned a non-JSON response.',
      );
    }

    if (failed) {
      final error = decoded['error'] as Map<String, dynamic>?;
      throw ApiException(
        statusCode: response.statusCode,
        code: error?['code'] as String? ?? 'unknown_error',
        message: error?['message'] as String? ?? 'Request failed.',
        details: error?['details'],
      );
    }

    return decoded;
  }

  void close() => _client.close();
}
