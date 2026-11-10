import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  ApiClient({http.Client? client, TargetPlatform? platform})
    : _client = client ?? http.Client(),
      _storage = const FlutterSecureStorage(),
      _platform = platform ?? defaultTargetPlatform,
      baseUrl = _resolveBaseUrl(platform ?? defaultTargetPlatform);

  static const _sessionKey = 'toystore_session';
  static const _customBaseUrlKey = 'toystore_custom_base_url';
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final TargetPlatform _platform;
  String baseUrl;
  String? _token;
  Map<String, dynamic>? session;

  static String _resolveBaseUrl(TargetPlatform platform) {
    final configured = _configuredUrl.trim();
    if (configured.isNotEmpty) {
      return _forPlatform(configured, platform).replaceFirst(
        RegExp(r'/+$'),
        '',
      );
    }

    if (!kIsWeb && platform == TargetPlatform.android) {
      return 'http://10.0.2.2:5225/api';
    }
    return 'http://localhost:5225/api';
  }

  static String _forPlatform(String value, TargetPlatform platform) {
    if (kIsWeb || platform != TargetPlatform.android) return value;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'localhost', '127.0.0.1', '::1'}.contains(uri.host.toLowerCase())) {
      return value;
    }
    return uri.replace(host: '10.0.2.2').toString();
  }

  Future<void> updateBaseUrl(String newUrl) async {
    final trimmed = _forPlatform(
      newUrl.trim(),
      _platform,
    ).replaceFirst(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return;
    baseUrl = trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
    await _storage.write(key: _customBaseUrlKey, value: baseUrl);
    if (kDebugMode) {
      debugPrint('[ApiClient] Updated Base URL: $baseUrl');
    }
  }

  Future<void> restoreSession() async {
    try {
      final customUrl = await _storage.read(key: _customBaseUrlKey);
      if (customUrl != null && customUrl.trim().isNotEmpty) {
        baseUrl = _forPlatform(
          customUrl.trim(),
          _platform,
        ).replaceFirst(RegExp(r'/+$'), '');
      }

      final stored = await _storage.read(key: _sessionKey);
      if (stored == null) return;

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
    } catch (_) {}
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

  Future<bool> checkHealth() async {
    try {
      await get('Health');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParameters}) =>
      _send('GET', path, queryParameters: queryParameters);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

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

    final uri = Uri.parse(_buildUrl('Upload/image'));
    final request = http.MultipartRequest('POST', uri)
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';

    final stopwatch = Stopwatch()..start();
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamed);
      stopwatch.stop();

      _logRequest(
        'POST (Upload)',
        uri,
        response.statusCode,
        stopwatch.elapsedMilliseconds,
      );

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
    } on TimeoutException {
      throw const ApiException(
        'Quá thời gian tải ảnh lên máy chủ. Vui lòng thử lại.',
      );
    } on SocketException catch (error) {
      throw ApiException('Không có kết nối mạng: ${error.message}');
    } on http.ClientException catch (error) {
      throw ApiException('Không thể tải ảnh lên: ${error.message}');
    } on Exception catch (error) {
      throw ApiException('Tải ảnh lên thất bại: $error');
    }
  }

  String absoluteAssetUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return trimmed;

    final root = baseUrl
        .replaceFirst(RegExp(r'/api/?$'), '')
        .replaceFirst(RegExp(r'/+$'), '');
    final cleanVal = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$root$cleanVal';
  }

  String _buildUrl(String path) {
    var cleanPath = path.trim();
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    if (cleanPath.toLowerCase().startsWith('api/')) {
      cleanPath = cleanPath.substring(4);
    }
    final root = baseUrl.endsWith('/api')
        ? baseUrl
        : '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api';
    return '$root/$cleanPath';
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final fullUrl = _buildUrl(path);
    final uri = Uri.parse(fullUrl).replace(queryParameters: queryParameters);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (_token != null) headers['Authorization'] = 'Bearer $_token';

    final stopwatch = Stopwatch()..start();
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(headers)
        ..followRedirects = false;
      if (body != null) request.body = jsonEncode(body);

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed);
      stopwatch.stop();

      _logRequest(
        method,
        uri,
        response.statusCode,
        stopwatch.elapsedMilliseconds,
      );

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
    } on TimeoutException {
      throw const ApiException(
        'Kết nối máy chủ bị quá thời gian (timeout). Vui lòng kiểm tra lại mạng hoặc server.',
      );
    } on SocketException catch (error) {
      throw ApiException(
        'Không thể kết nối tới máy chủ (${error.address?.address ?? baseUrl}). Vui lòng kiểm tra địa chỉ API.',
      );
    } on http.ClientException catch (error) {
      throw ApiException('Không thể kết nối máy chủ: ${error.message}');
    } on FormatException {
      throw const ApiException(
        'Máy chủ trả về dữ liệu không đúng định dạng JSON.',
      );
    } on Exception catch (error) {
      throw ApiException('Yêu cầu máy chủ thất bại: $error');
    }
  }

  void _logRequest(String method, Uri uri, int statusCode, int durationMs) {
    if (kDebugMode) {
      final statusColor = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
      debugPrint(
        '[HTTP $statusColor] $method ${uri.path}${uri.hasQuery ? '?${uri.query}' : ''} -> $statusCode (${durationMs}ms)',
      );
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
          response['message'] ??
          response['title'] ??
          response['error'] ??
          response['detail'];
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
      case 400:
        return 'Yêu cầu không hợp lệ. Vui lòng kiểm tra lại thông tin đã nhập.';
      case 401:
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
      case 403:
        return 'Tài khoản của bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu yêu cầu trên hệ thống.';
      case 409:
        return 'Dữ liệu bị xung đột hoặc đã tồn tại trên hệ thống.';
      case 500:
        return 'Máy chủ gặp sự cố xử lý nội bộ (500). Vui lòng thử lại sau.';
      default:
        return 'Máy chủ trả về mã lỗi HTTP $statusCode.';
    }
  }

  void close() => _client.close();
}
