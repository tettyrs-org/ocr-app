import 'package:oidc/oidc.dart';

import 'auth_config.dart';
import 'auth_store.dart';

class AuthService {
  AuthService._(this._manager);

  final OidcUserManager _manager;

  static Future<AuthService> create({required Uri baseUri}) async {
    final manager = OidcUserManager.lazy(
      discoveryDocumentUri: Uri.parse(AuthConfig.discoveryUri),
      clientCredentials: const OidcClientAuthentication.none(
        clientId: AuthConfig.clientId,
      ),
      store: createAuthStore(),
      settings: OidcUserManagerSettings(
        redirectUri: Uri.parse(
          AuthConfig.redirectUri(isWeb: AuthConfig.isWeb, baseUri: baseUri),
        ),
        scope: AuthConfig.scopes,
        options: const OidcPlatformSpecificOptions(
          web: OidcPlatformSpecificOptions_Web(
            navigationMode: OidcPlatformSpecificOptions_Web_NavigationMode.popup,
          ),
        ),
      ),
    );
    await manager.init();
    return AuthService._(manager);
  }

  OidcUser? get currentUser => _manager.currentUser;

  Future<void> login() async {
    await _manager.loginAuthorizationCodeFlow();
  }

  Future<void> logout() async {
    await _manager.logout();
  }
}
