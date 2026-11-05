import 'demo_flag.dart';
import 'demo_mode.dart';
import 'sign_in.dart';

/// Membungkus login asli. Email demo hanya menyalakan mode demo dan tidak memanggil controller asli.
class DemoAwareSignIn implements SignInController {
  DemoAwareSignIn(this.inner);

  final SignInController inner;

  @override
  Future<bool> restore() async {
    if (DemoMode.active || flagDemoTersimpan()) {
      DemoMode.active = true;
      return true;
    }
    return inner.restore();
  }

  @override
  Future<void> login(String email, String password) async {
    if (email == kDemoEmail) {
      DemoMode.active = true;
      simpanFlagDemo(true);
      return;
    }
    DemoMode.active = false;
    simpanFlagDemo(false);
    await inner.login(email, password);
  }

  @override
  Future<void> logout() async {
    if (DemoMode.active) {
      DemoMode.active = false;
      simpanFlagDemo(false);
      return;
    }
    await inner.logout();
  }
}
