import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ocr_app/auth/bff_service.dart';

const _base = 'https://ocr-app-6r2.pages.dev';

void main() {
  test('currentUser mengembalikan null bila 401 (belum login)', () async {
    final client = MockClient((_) async => http.Response('{"error":"UNAUTHENTICATED"}', 401));
    final bff = BffService(baseUrl: _base, client: client);

    expect(await bff.currentUser(), isNull);
  });

  test('currentUser membaca identitas dan menyimpan CSRF token', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), '$_base/bff/me');
      return http.Response(
        jsonEncode({'sub': 'u1', 'roles': ['USER'], 'csrfToken': 'abc'}),
        200,
      );
    });
    final bff = BffService(baseUrl: _base, client: client);

    final user = await bff.currentUser();

    expect(user?.sub, 'u1');
    expect(user?.roles, ['USER']);
  });

  test('tulisan ke API membawa X-CSRF-Token dan melewati /bff/api', () async {
    late http.BaseRequest captured;
    final client = MockClient.streaming((request, _) async {
      if (request.url.path == '/bff/me') {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'sub': 'u1', 'roles': ['USER'], 'csrfToken': 'tok'}))),
          200,
        );
      }
      captured = request;
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 202);
    });
    final bff = BffService(baseUrl: _base, client: client);
    await bff.currentUser();

    await bff.apiWrite('POST', '/api/v1/documents', body: '{}', headers: {'Content-Type': 'application/json'});

    expect(captured.url.toString(), '$_base/bff/api/api/v1/documents');
    expect(captured.headers['X-CSRF-Token'], 'tok');
  });

  test('tulisan tanpa currentUser lebih dulu ditolak', () async {
    final bff = BffService(baseUrl: _base, client: MockClient((_) async => http.Response('', 200)));

    expect(
      () => bff.apiWrite('POST', '/api/v1/documents'),
      throwsStateError,
    );
  });
}
