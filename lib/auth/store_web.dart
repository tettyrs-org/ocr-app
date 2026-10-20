import 'package:oidc/oidc.dart';

import 'key_value_store.dart';

OidcStore createAuthStore() => KeyValueOidcStore(MemoryKeyValueBackend());
