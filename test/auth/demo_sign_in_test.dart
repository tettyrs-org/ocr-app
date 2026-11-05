import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/auth/demo_mode.dart';
import 'package:ocr_app/auth/demo_sign_in.dart';
import 'package:ocr_app/auth/sign_in.dart';

class _FakeSignIn implements SignInController {
  int loginCount = 0;
  int logoutCount = 0;
  bool restored = false;

  @override
  Future<bool> restore() async => restored;

  @override
  Future<void> login(String email, String password) async => loginCount++;

  @override
  Future<void> logout() async => logoutCount++;
}

void main() {
  setUp(() => DemoMode.active = false);
  tearDown(() => DemoMode.active = false);

  test('email demo menyalakan mode demo tanpa memanggil login asli', () async {
    final inner = _FakeSignIn();
    final sut = DemoAwareSignIn(inner);

    await sut.login(kDemoEmail, '');

    expect(DemoMode.active, isTrue);
    expect(inner.loginCount, 0);
  });

  test('email biasa meneruskan login ke controller asli dan mematikan mode demo', () async {
    final inner = _FakeSignIn();
    final sut = DemoAwareSignIn(inner);
    DemoMode.active = true;

    await sut.login('pegawai@example.com', 'rahasia');

    expect(DemoMode.active, isFalse);
    expect(inner.loginCount, 1);
  });

  test('restore di mode demo selalu berhasil tanpa menyentuh controller asli', () async {
    final inner = _FakeSignIn();
    final sut = DemoAwareSignIn(inner);
    DemoMode.active = true;

    expect(await sut.restore(), isTrue);
  });

  test('logout di mode demo hanya mematikan mode demo', () async {
    final inner = _FakeSignIn();
    final sut = DemoAwareSignIn(inner);
    DemoMode.active = true;

    await sut.logout();

    expect(DemoMode.active, isFalse);
    expect(inner.logoutCount, 0);
  });

  test('logout di luar mode demo diteruskan ke controller asli', () async {
    final inner = _FakeSignIn();
    final sut = DemoAwareSignIn(inner);

    await sut.logout();

    expect(inner.logoutCount, 1);
  });
}
