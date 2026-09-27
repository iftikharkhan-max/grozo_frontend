import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Result of an API call. [data] is the decoded JSON body on success.
class ApiResult {
  final int status;
  final dynamic data;
  final String? errorCode;
  final String? message;

  const ApiResult(this.status, this.data, {this.errorCode, this.message});

  bool get ok => status >= 200 && status < 300;
  bool get isNetworkError => status == 0;
}

/// Single place that talks to the backend. Adds the login token to every
/// request and turns failures into plain-language messages.
class Api {
  static String? token;

  /// Called when the server says the session is no longer valid.
  static void Function()? onSessionExpired;

  static const _timeout = Duration(seconds: 30);

  /// HTTP client; tests replace it with a fake that replays recorded responses.
  static http.Client client = http.Client();

  /// Headers for callers that still use `http` directly (staff screens).
  static Map<String, String> get jsonHeaders => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Map<String, String> get authHeaders => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${Config.baseUrl}$path').replace(queryParameters: query);

  static Future<ApiResult> get(String path, {Map<String, String>? query}) =>
      _send(() => client.get(_uri(path, query), headers: jsonHeaders));

  static Future<ApiResult> post(String path, [Object? body]) =>
      _send(() => client.post(_uri(path), headers: jsonHeaders, body: jsonEncode(body ?? {})));

  static Future<ApiResult> put(String path, [Object? body]) =>
      _send(() => client.put(_uri(path), headers: jsonHeaders, body: jsonEncode(body ?? {})));

  static Future<ApiResult> delete(String path) =>
      _send(() => client.delete(_uri(path), headers: jsonHeaders));

  /// Sends form fields plus an optional image (multipart), e.g. product with photo.
  /// Null field values are sent as empty strings, which the server stores as "not set".
  static Future<ApiResult> sendForm(String method, String path, Map<String, dynamic> fields, {File? image}) {
    return _send(() async {
      final req = http.MultipartRequest(method, _uri(path))
        ..headers.addAll(authHeaders)
        ..fields.addAll(fields.map((k, v) => MapEntry(k, v == null ? '' : v.toString())));
      if (image != null) req.files.add(await http.MultipartFile.fromPath('image', image.path));
      return http.Response.fromStream(await client.send(req));
    });
  }

  static Future<ApiResult> _send(Future<http.Response> Function() request) async {
    try {
      final res = await request().timeout(_timeout);
      dynamic body;
      try {
        body = res.body.isEmpty ? null : jsonDecode(res.body);
      } catch (_) {
        body = null;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) return ApiResult(res.statusCode, body);

      final map = body is Map ? body : const {};
      final code = map['error']?.toString();
      final message = (map['message'] ?? map['error'])?.toString();
      if (res.statusCode == 401 && code == 'session_expired' && token != null) {
        onSessionExpired?.call();
      }
      return ApiResult(res.statusCode, body, errorCode: code, message: message);
    } on SocketException {
      return const ApiResult(0, null, errorCode: 'network');
    } on TimeoutException {
      return const ApiResult(0, null, errorCode: 'network');
    } on http.ClientException {
      return const ApiResult(0, null, errorCode: 'network');
    }
  }

  static String imageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${Config.rootUrl}$path';
  }
}
