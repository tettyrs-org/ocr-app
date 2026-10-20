import 'package:flutter/foundation.dart';

abstract final class AuthConfig {
  static const issuer = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: 'https://auth-ocr-x7q2.nouman.my.id/realms/ocr',
  );
  static const clientId = 'ocr-app';
  static const mobileRedirectUri = 'com.tettyrs.ocr:/callback';
  static const scopes = ['openid', 'profile'];

  static String get discoveryUri => '$issuer/.well-known/openid-configuration';

  static String redirectUri({required bool isWeb, required Uri baseUri}) {
    if (isWeb) {
      return baseUri.resolve('redirect.html').toString();
    }
    return mobileRedirectUri;
  }

  static bool get isWeb => kIsWeb;
}
