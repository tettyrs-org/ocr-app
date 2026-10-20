import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/auth/auth_config.dart';

void main() {
  test('redirect web berada di origin aplikasi, bukan skema khusus', () {
    final uri = AuthConfig.redirectUri(
      isWeb: true,
      baseUri: Uri.parse('https://your-app-host.web.app/'),
    );
    expect(uri, 'https://your-app-host.web.app/redirect.html');
  });

  test('redirect mobile memakai skema khusus yang terdaftar di Keycloak', () {
    final uri = AuthConfig.redirectUri(
      isWeb: false,
      baseUri: Uri.parse('https://your-app-host.web.app/'),
    );
    expect(uri, 'com.tettyrs.ocr:/callback');
  });

  test('discovery mengarah ke issuer Keycloak', () {
    expect(
      AuthConfig.discoveryUri,
      'https://auth-ocr-x7q2.nouman.my.id/realms/ocr/.well-known/openid-configuration',
    );
  });
}
