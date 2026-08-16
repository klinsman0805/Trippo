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
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// e.g. `http://10.0.2.2:8080` on the Android emulator, since `localhost`
  /// there refers to the emulator itself, not the host machine.
  final String baseUrl;
  final http.Client _client;

  /// Planner calls run for minutes with adaptive thinking, so the default
  /// client timeout is far too aggressive for them — see [postLongRunning].
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _plannerTimeout = Duration(minutes: 8);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/v1$path').replace(
        queryParameters: query?.isEmpty ?? true ? null : query,
      );

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async =>
      _send(() => _client.get(_uri(path, query)), _defaultTimeout);

  /// GET a path outside the `/v1` prefix, e.g. `/health`.
  Future<Map<String, dynamic>> getUnversioned(String path) async =>
      _send(() => _client.get(Uri.parse('$baseUrl$path')), _defaultTimeout);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? timeout,
  }) async =>
      _send(
        () => _client.post(
          _uri(path),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body ?? const {}),
        ),
        timeout ?? _defaultTimeout,
      );

  /// For endpoints that legitimately take minutes (plan generation, imports).
  Future<Map<String, dynamic>> postLongRunning(String path, {Object? body}) =>
      post(path, body: body, timeout: _plannerTimeout);

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async => _send(
        () => _client.patch(
          _uri(path),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body ?? const {}),
        ),
        _defaultTimeout,
      );

  Future<void> delete(String path) async {
    await _send(() => _client.delete(_uri(path)), _defaultTimeout);
  }

  /// DELETE where the response body matters — removing an activity returns the
  /// updated plan, so the client does not have to refetch it.
  Future<Map<String, dynamic>> deleteReturning(String path) =>
      _send(() => _client.delete(_uri(path)), _defaultTimeout);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
    Duration timeout,
  ) async {
    late http.Response response;
    try {
      response = await request().timeout(timeout);
    } on SocketException catch (e) {
      throw ApiException(
        statusCode: 0,
        code: 'network_error',
        message: 'Could not reach the server: ${e.message}',
      );
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
