import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Klien web memakai cookie sesi BFF. `idTokenProvider` tidak dipakai di web.
http.Client createBffClient({Future<String?> Function()? idTokenProvider}) {
  final client = BrowserClient();
  client.withCredentials = true;
  return client;
}
