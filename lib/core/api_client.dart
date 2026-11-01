import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client})
    : _client = client ?? http.Client(),
      _storage = const FlutterSecureStorage(),
      baseUrl = _resolveBaseUrl();

  static const _sessionKey = 'toystore_session';
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String baseUrl;
  String? _token;
  Map<String, dynamic>? session;

  static String _resolveBaseUrl() {
    final configured = _configuredUrl.trim();
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5225/api';
    }
    return 'http://localhost:5225/api';
  }

  Future<void> restoreSession() async {
    final stored = await _storage.read(key: _sessionKey);
    if (stored == null) return;

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic> ||
          decoded['token'] is! String ||
          decoded['expiration'] is! String) {
        await clearSession();
        return;
      }

      final expiration = DateTime.tryParse(decoded['expiration'] as String);
      if (expiration == null || !expiration.isAfter(DateTime.now())) {
        await clearSession();
        return;
      }

      session = decoded;
      _token = decoded['token'] as String;
    } on FormatException {
      await clearSession();
    }
  }

  Future<void> saveSession(Map<String, dynamic> value) async {
    final token = value['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiException('Máy chủ không trả về mã đăng nhập hợp lệ.');
    }

    final normalized = <String, dynamic>{
      ...value,
      'expiration': value['expiration']?.toString() ?? '',
    };
    session = normalized;
    _token = token;
    await _storage.write(key: _sessionKey, value: jsonEncode(normalized));
  }

  Future<void> clearSession() async {
    session = null;
    _token = null;
    await _storage.delete(key: _sessionKey);
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParameters}) =>
      _send('GET', path, queryParameters: queryParameters);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> uploadImage(
    Uint8List bytes,
    String fileName, {
    String folder = 'products',
  }) async {
    if (bytes.isEmpty) throw const ApiException('Ảnh được chọn đang trống.');
    if (bytes.length > 10 * 1024 * 1024) {
      throw const ApiException('Ảnh không được vượt quá 10 MB.');
    }

    final normalizedPath = 'Upload/image';
    final root = baseUrl.endsWith('/api')
        ? baseUrl
        : '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api';
    final uri = Uri.parse('$root/$normalizedPath');
    final request = http.MultipartRequest('POST', uri)
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    if (_token != null) request.headers['Authorization'] = '******';

    try {
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty ? null : _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _errorMessage(decoded, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw ApiException('Không thể tải ảnh lên: ${error.message}');
    } on Exception catch (error) {
      throw ApiException('Tải ảnh lên thất bại: $error');
    }
  }

  String absoluteAssetUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    if (uri.hasScheme) return value;
    final apiUri = Uri.parse(baseUrl);
    return apiUri.resolve(value).toString();
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final root = baseUrl.endsWith('/api')
        ? baseUrl
        : '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api';
    final uri = Uri.parse(
      '$root/$normalizedPath',
    ).replace(queryParameters: queryParameters);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (_token != null) headers['Authorization'] = 'Bearer $_token';

    try {
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..followRedirects = false;
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty ? null : _decode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _errorMessage(decoded, response.statusCode),
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on http.ClientException catch (error) {
      throw ApiException('Không thể kết nối máy chủ: ${error.message}');
    } on FormatException {
      throw const ApiException('Máy chủ trả về dữ liệu không đúng định dạng.');
    } on Exception catch (error) {
      throw ApiException('Yêu cầu máy chủ thất bại: $error');
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  String _errorMessage(dynamic response, int statusCode) {
    if (response is Map) {
      final message =
          response['message'] ?? response['title'] ?? response['error'];
      if (message is String && message.isNotEmpty) return message;
      final errors = response['errors'];
      if (errors is Map) {
        final messages = errors.values
            .expand((value) => value is List ? value : [value])
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }
    }

    switch (statusCode) {
      case 401:
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
      case 403:
        return 'Tài khoản của bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu yêu cầu.';
      default:
        return 'Máy chủ trả về lỗi HTTP $statusCode.';
    }
  }

  void close() => _client.close();
}
