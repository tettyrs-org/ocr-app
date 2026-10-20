import 'dart:convert';

import 'package:http/http.dart' as http;

import 'bff_client.dart';

class BffUser {
  const BffUser({required this.sub, required this.roles, required this.csrfToken});

  final String sub;
  final List<String> roles;
  final String csrfToken;
}

class BffService {
  BffService({required this.baseUrl, http.Client? client})
      : _client = client ?? createBffClient();

  final String baseUrl;
  final http.Client _client;
  String? _csrfToken;

  Future<BffUser?> currentUser() async {
    final res = await _client.get(Uri.parse('$baseUrl/bff/me'));
    if (res.statusCode == 401) {
      _csrfToken = null;
      return null;
    }
    if (res.statusCode != 200) {
      throw http.ClientException('BFF /me gagal: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final user = BffUser(
      sub: body['sub'] as String,
      roles: (body['roles'] as List).cast<String>(),
      csrfToken: body['csrfToken'] as String,
    );
    _csrfToken = user.csrfToken;
    return user;
  }

  /// Menukar ID token Firebase dengan sesi cookie di BFF.
  /// Dipanggil saat login dan setiap kali ID token baru diperoleh.
  /// Kontrak: documents/tech/auth-firebase.md bagian 4 dan 5.
  Future<BffUser> exchangeIdToken(String idToken) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/bff/session'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (res.statusCode != 200) {
      _csrfToken = null;
      throw http.ClientException('BFF /session gagal: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final user = BffUser(
      sub: body['sub'] as String,
      roles: (body['roles'] as List).cast<String>(),
      csrfToken: body['csrfToken'] as String,
    );
    _csrfToken = user.csrfToken;
    return user;
  }

  Future<void> logout() async {
    final token = _csrfToken;
    if (token == null) return;
    await _client.post(
      Uri.parse('$baseUrl/bff/logout'),
      headers: {'X-CSRF-Token': token},
    );
    _csrfToken = null;
  }

  Future<http.Response> apiGet(String path) {
    return _client.get(Uri.parse('$baseUrl/bff/api$path'));
  }

  /// Unggah berkas sebagai multipart. `Idempotency-Key` dipakai agar percobaan ulang tidak membuat dokumen ganda.
  Future<http.Response> apiUpload(
    String path, {
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
    Map<String, String> fields = const {},
  }) async {
    final token = _csrfToken;
    if (token == null) {
      throw StateError('CSRF token belum tersedia. Panggil currentUser() dulu.');
    }
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/bff/api$path'))
      ..headers.addAll({'X-CSRF-Token': token, 'Idempotency-Key': idempotencyKey})
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await _client.send(request);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> apiWrite(
    String method,
    String path, {
    Map<String, String>? headers,
    String? body,
  }) {
    final token = _csrfToken;
    if (token == null) {
      throw StateError('CSRF token belum tersedia. Panggil currentUser() dulu.');
    }
    final request = http.Request(method, Uri.parse('$baseUrl/bff/api$path'))
      ..headers.addAll({'X-CSRF-Token': token, ...?headers});
    if (body != null) request.body = body;
    return _client.send(request).then(http.Response.fromStream);
  }
}
