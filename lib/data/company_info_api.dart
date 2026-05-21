import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../services/bc/bc_odata_client.dart';
import '../services/bc/bc_settings_store.dart';
import 'company_info_model.dart';

class CompanyInfoApi {
  CompanyInfoApi({BcODataClient? client}) : _client = client ?? BcODataClient();

  final BcODataClient _client;

  Future<CompanyInfo?> fetchCompanyInfo() async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return null;
    }

    List<Map<String, Object?>> rows = const [];
    try {
      rows = await _client.getAll(settings, 'Companyinfo', top: 1);
    } catch (_) {
      rows = await _client.getAll(settings, 'CompanyInfo', top: 1);
    }
    if (rows.isEmpty) return null;

    final row = rows.first;
    final picture = await _fetchCompanyPicture(
      row,
      settings.odataBaseUrl,
      settings.username,
      settings.password,
    );

    return CompanyInfo(
      name: (row['Name'] as String?)?.trim() ?? '',
      address: (row['Address'] as String?)?.trim() ?? '',
      phoneNo: (row['Phone_No'] as String?)?.trim() ?? '',
      email: (row['E_Mail'] as String?)?.trim() ?? '',
      pictureBytes: picture?.bytes,
      pictureMime: picture?.mime ?? '',
    );
  }

  Future<_CompanyPicture?> _fetchCompanyPicture(
    Map<String, Object?> row,
    String odataBaseUrl,
    String username,
    String password,
  ) async {
    final mediaLink =
        (row['Picture@odata.mediaReadLink'] as String?) ??
        (row['Picture@odata.mediaEditLink'] as String?) ??
        (row['picture@odata.mediaReadLink'] as String?) ??
        (row['picture@odata.mediaEditLink'] as String?);
    if (mediaLink == null || mediaLink.trim().isEmpty) {
      return null;
    }

    final base = Uri.parse(odataBaseUrl.trim().replaceAll(RegExp(r'/+$'), '/'));
    final mediaUri = Uri.parse(mediaLink);
    final resolvedUri = mediaUri.hasScheme
        ? mediaUri
        : base.resolveUri(mediaUri);

    final raw = '$username:$password';
    final auth = base64Encode(utf8.encode(raw));
    final response = await http.get(
      resolvedUri,
      headers: {
        'Authorization': 'Basic $auth',
        'Accept': 'image/*,application/octet-stream',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    return _CompanyPicture(
      bytes: response.bodyBytes,
      mime: (response.headers['content-type'] ?? '').trim(),
    );
  }
}

class _CompanyPicture {
  const _CompanyPicture({required this.bytes, required this.mime});

  final Uint8List bytes;
  final String mime;
}
