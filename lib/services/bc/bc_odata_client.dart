import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'bc_settings.dart';

class BcODataClient {
  final http.Client _http;

  BcODataClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Uri _collectionUri(
    BcSettings settings,
    String serviceName, {
    Map<String, String>? query,
  }) {
    final base = settings.odataBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final company = Uri.encodeComponent(settings.company.trim());
    final path = '$base/Company(\'$company\')/$serviceName';
    final uri = Uri.parse(path);
    return uri.replace(queryParameters: query);
  }

  Uri _singleKeyEntityUri(
    BcSettings settings,
    String serviceName,
    Object keyValue,
  ) {
    final base = settings.odataBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final company = Uri.encodeComponent(settings.company.trim());
    final path =
        '$base/Company(\'$company\')/$serviceName(${_odataKeyLiteral(keyValue)})';
    return Uri.parse(path);
  }

  Map<String, String> _headers(BcSettings settings) {
    final raw = '${settings.username}:${settings.password}';
    final auth = base64Encode(utf8.encode(raw));
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Basic $auth',
      'OData-MaxVersion': '4.0',
      'OData-Version': '4.0',
    };
  }

  Future<List<Map<String, Object?>>> getAll(
    BcSettings settings,
    String serviceName, {
    int top = 2000,
    Map<String, String>? query,
  }) async {
    final q = <String, String>{'\$top': '$top', ...?query};
    var uri = _collectionUri(settings, serviceName, query: q);
    final rows = <Map<String, Object?>>[];

    while (true) {
      late final http.Response resp;
      try {
        resp = await _http.get(uri, headers: _headers(settings));
      } catch (error, stackTrace) {
        _logHttpException(
          method: 'GET',
          uri: uri,
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        _logHttpFailure(method: 'GET', uri: uri, response: resp);
        throw Exception('OData GET failed (${resp.statusCode}): ${resp.body}');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        throw Exception('Unexpected OData response: ${resp.body}');
      }

      final value = decoded['value'];
      if (value is List) {
        for (final item in value) {
          if (item is Map) {
            rows.add(item.cast<String, Object?>());
          }
        }
      }

      final nextLink = decoded['@odata.nextLink'];
      if (nextLink is String && nextLink.isNotEmpty) {
        uri = Uri.parse(nextLink);
        continue;
      }

      return rows;
    }
  }

  Future<Map<String, Object?>> create(
    BcSettings settings,
    String serviceName,
    Map<String, Object?> payload,
  ) async {
    final uri = _collectionUri(settings, serviceName);
    late final http.Response resp;
    try {
      resp = await _http.post(
        uri,
        headers: _headers(settings),
        body: jsonEncode(payload),
      );
    } catch (error, stackTrace) {
      _logHttpException(
        method: 'POST',
        uri: uri,
        error: error,
        stackTrace: stackTrace,
        payload: payload,
      );
      rethrow;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      _logHttpFailure(
        method: 'POST',
        uri: uri,
        response: resp,
        payload: payload,
      );
      throw Exception('OData POST failed (${resp.statusCode}): ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map) {
      return decoded.cast<String, Object?>();
    }
    return <String, Object?>{};
  }

  Future<void> patchByOdataId(
    BcSettings settings,
    String odataId,
    Map<String, Object?> payload, {
    String? etag,
  }) async {
    final uri = Uri.parse(odataId);
    final headers = _headers(settings);
    if (etag != null && etag.isNotEmpty) {
      headers['If-Match'] = etag;
    } else {
      headers['If-Match'] = '*';
    }

    late final http.Response resp;
    try {
      resp = await _http.patch(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );
    } catch (error, stackTrace) {
      _logHttpException(
        method: 'PATCH',
        uri: uri,
        error: error,
        stackTrace: stackTrace,
        payload: payload,
      );
      rethrow;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      _logHttpFailure(
        method: 'PATCH',
        uri: uri,
        response: resp,
        payload: payload,
      );
      throw Exception('OData PATCH failed (${resp.statusCode}): ${resp.body}');
    }
  }

  Future<void> patchBySingleKey(
    BcSettings settings,
    String serviceName,
    Object keyValue,
    Map<String, Object?> payload, {
    String? etag,
  }) async {
    final uri = _singleKeyEntityUri(settings, serviceName, keyValue);
    final headers = _headers(settings);
    if (etag != null && etag.isNotEmpty) {
      headers['If-Match'] = etag;
    } else {
      headers['If-Match'] = '*';
    }

    late final http.Response resp;
    try {
      resp = await _http.patch(
        uri,
        headers: headers,
        body: jsonEncode(payload),
      );
    } catch (error, stackTrace) {
      _logHttpException(
        method: 'PATCH',
        uri: uri,
        error: error,
        stackTrace: stackTrace,
        payload: payload,
      );
      rethrow;
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      _logHttpFailure(
        method: 'PATCH',
        uri: uri,
        response: resp,
        payload: payload,
      );
      throw Exception('OData PATCH failed (${resp.statusCode}): ${resp.body}');
    }
  }

  void _logHttpFailure({
    required String method,
    required Uri uri,
    required http.Response response,
    Map<String, Object?>? payload,
  }) {
    debugPrint(
      'BC $method failed\n'
      'URL: $uri\n'
      'Status: ${response.statusCode}\n'
      'Payload: ${_formatPayload(payload)}\n'
      'Response: ${response.body}',
    );
  }

  void _logHttpException({
    required String method,
    required Uri uri,
    required Object error,
    required StackTrace stackTrace,
    Map<String, Object?>? payload,
  }) {
    debugPrint(
      'BC $method exception\n'
      'URL: $uri\n'
      'Payload: ${_formatPayload(payload)}\n'
      'Error: $error\n'
      '$stackTrace',
    );
  }

  String _formatPayload(Map<String, Object?>? payload) {
    if (payload == null) {
      return '<none>';
    }

    final sanitized = <String, Object?>{};
    payload.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      if (lowerKey.contains('password')) {
        sanitized[key] = '***';
      } else {
        sanitized[key] = value;
      }
    });
    return jsonEncode(sanitized);
  }

  String _odataKeyLiteral(Object keyValue) {
    if (keyValue is num || keyValue is bool) {
      return '$keyValue';
    }

    final raw = keyValue.toString().replaceAll("'", "''");
    return "'$raw'";
  }
}
