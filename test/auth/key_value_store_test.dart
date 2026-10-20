import 'package:flutter_test/flutter_test.dart';
import 'package:oidc/oidc.dart';
import 'package:ocr_app/auth/key_value_store.dart';

void main() {
  late KeyValueOidcStore store;

  setUp(() {
    store = KeyValueOidcStore(MemoryKeyValueBackend());
  });

  test('menyimpan dan membaca nilai per namespace', () async {
    await store.set(OidcStoreNamespace.session, key: 'access', value: 'abc');

    expect(
      await store.get(OidcStoreNamespace.session, key: 'access'),
      'abc',
    );
    expect(
      await store.get(OidcStoreNamespace.state, key: 'access'),
      isNull,
    );
  });

  test('menghapus nilai tanpa memengaruhi key lain', () async {
    await store.setMany(
      OidcStoreNamespace.session,
      values: {'access': 'a', 'refresh': 'r'},
    );

    await store.remove(OidcStoreNamespace.session, key: 'access');

    expect(await store.getAllKeys(OidcStoreNamespace.session), {'refresh'});
  });

  test('manajer berbeda tidak saling menimpa', () async {
    await store.set(OidcStoreNamespace.session, key: 'k', value: '1', managerId: 'a');
    await store.set(OidcStoreNamespace.session, key: 'k', value: '2', managerId: 'b');

    expect(
      await store.get(OidcStoreNamespace.session, key: 'k', managerId: 'a'),
      '1',
    );
  });
}
