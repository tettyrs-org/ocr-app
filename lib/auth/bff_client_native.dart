import 'package:http/http.dart' as http;

/// Klien native (Android dan iOS). Tidak ada cookie, jadi setiap permintaan membawa ID token Firebase
/// sebagai `Authorization: Bearer`. BFF memverifikasi token itu di setiap request (lihat documents/tech/auth-firebase.md).
http.Client createBffClient({Future<String?> Function()? idTokenProvider}) {
  if (idTokenProvider == null) return http.Client();
  return _BearerClient(http.Client(), idTokenProvider);
}

class _BearerClient extends http.BaseClient {
  _BearerClient(this._inner, this._idToken);

  final http.Client _inner;
  final Future<String?> Function() _idToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _idToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
