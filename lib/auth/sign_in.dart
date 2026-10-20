import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'bff_service.dart';

abstract interface class SignInController {
  Future<bool> restore();
  Future<void> login(String email, String password);
  Future<void> logout();
}

class OidcSignIn implements SignInController {
  OidcSignIn(this._auth);

  final AuthService _auth;

  @override
  Future<bool> restore() async => _auth.currentUser != null;

  // Alur native masih memakai OIDC browser; email dan password tidak dipakai.
  @override
  Future<void> login(String email, String password) => _auth.login();

  @override
  Future<void> logout() => _auth.logout();
}

/// Login web: email dan password lewat Firebase Authentication, lalu ID token ditukar
/// dengan sesi cookie di BFF. Kontrak: documents/tech/auth-firebase.md.
class FirebaseSignIn implements SignInController {
  FirebaseSignIn(this._bff, {FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  // ID token Firebase berlaku 1 jam, jadi sesi BFF diperbarui sebelum itu.
  static const _renewEvery = Duration(minutes: 50);

  final BffService _bff;
  final FirebaseAuth _auth;
  Timer? _renewTimer;

  BffService get service => _bff;

  @override
  Future<bool> restore() async {
    if (_auth.currentUser == null) return false;
    final ok = await _exchange();
    if (ok) _scheduleRenewal();
    return ok;
  }

  @override
  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final ok = await _exchange();
    if (!ok) {
      await _auth.signOut();
      throw StateError('Akun belum memiliki akses. Hubungi admin.');
    }
    _scheduleRenewal();
  }

  @override
  Future<void> logout() async {
    _renewTimer?.cancel();
    try {
      await _bff.logout();
    } finally {
      await _auth.signOut();
    }
  }

  /// Ambil ID token terbaru (Firebase memperbaruinya otomatis bila perlu), lalu tukar ke sesi BFF.
  Future<bool> _exchange() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdToken();
    if (token == null) return false;
    try {
      await _bff.exchangeIdToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _scheduleRenewal() {
    _renewTimer?.cancel();
    _renewTimer = Timer.periodic(_renewEvery, (_) async {
      final ok = await _exchange();
      if (!ok) {
        _renewTimer?.cancel();
        await _auth.signOut();
      }
    });
  }
}
