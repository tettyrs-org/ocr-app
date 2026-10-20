import 'package:oidc/oidc.dart';

abstract interface class KeyValueBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

class MemoryKeyValueBackend implements KeyValueBackend {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(_values);
}

class KeyValueOidcStore implements OidcStore {
  KeyValueOidcStore(this._backend);

  final KeyValueBackend _backend;

  String _key(OidcStoreNamespace namespace, String? managerId, String key) =>
      '${namespace.name}|${managerId ?? ''}|$key';

  String _prefix(OidcStoreNamespace namespace, String? managerId) =>
      '${namespace.name}|${managerId ?? ''}|';

  @override
  Future<void> init() async {}

  @override
  Future<Set<String>> getAllKeys(
    OidcStoreNamespace namespace, {
    String? managerId,
  }) async {
    final prefix = _prefix(namespace, managerId);
    final all = await _backend.readAll();
    return all.keys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toSet();
  }

  @override
  Future<Map<String, String>> getMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    final result = <String, String>{};
    for (final key in keys) {
      final value = await _backend.read(_key(namespace, managerId, key));
      if (value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  @override
  Future<void> setMany(
    OidcStoreNamespace namespace, {
    required Map<String, String> values,
    String? managerId,
  }) async {
    for (final entry in values.entries) {
      await _backend.write(_key(namespace, managerId, entry.key), entry.value);
    }
  }

  @override
  Future<void> removeMany(
    OidcStoreNamespace namespace, {
    required Set<String> keys,
    String? managerId,
  }) async {
    for (final key in keys) {
      await _backend.delete(_key(namespace, managerId, key));
    }
  }
}
