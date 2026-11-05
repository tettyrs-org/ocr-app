import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/profile/profile_api.dart';
import 'demo_mode.dart';
import 'sign_in.dart';

/// Status sesi untuk router. Setiap perubahan memicu pengecekan ulang rute (lihat router/app_router.dart).
enum SessionStatus { loading, signedOut, profileIncomplete, ready }

/// Pemilik sesi aplikasi: memulihkan sesi, memuat profil, dan mengumumkan perubahan status ke router.
class AppSession extends ChangeNotifier {
  AppSession({required this.signIn, this.profileApi, this.loadRoles});

  final SignInController signIn;

  /// Null bila tidak ada BFF (mis. jalur OIDC non-web). Tanpa profil, sesi langsung dianggap siap.
  final ProfileApi? profileApi;

  /// Mengambil peran pengguna dari BFF (USER, ADMIN, VIEWER). Null di jalur tanpa BFF.
  final Future<List<String>> Function()? loadRoles;

  SessionStatus _status = SessionStatus.loading;
  MeProfile? _profile;
  List<String> _roles = const [];
  String? _error;

  SessionStatus get status => _status;
  MeProfile? get profile => _profile;
  List<String> get roles => _roles;

  /// Pesan terakhir yang perlu ditampilkan di halaman masuk (mis. profil gagal dimuat).
  String? get error => _error;

  /// Batas waktu tiap langkah pemulihan. Tanpa ini, jaringan yang macet membuat halaman memuat tanpa akhir.
  static const _stepTimeout = Duration(seconds: 15);

  Future<void> start() async {
    final bool restored;
    try {
      restored = await signIn.restore().timeout(_stepTimeout);
    } on TimeoutException {
      _error = 'Sesi belum bisa dipulihkan. Periksa jaringan lalu masuk lagi.';
      _set(SessionStatus.signedOut);
      return;
    }
    if (!restored) {
      _set(SessionStatus.signedOut);
      return;
    }
    // Mode demo tidak punya profil di server.
    if (DemoMode.active) {
      _set(SessionStatus.ready);
      return;
    }
    await _loadProfile();
  }

  /// Dipanggil dari halaman masuk. Error dilempar kembali agar halaman bisa menampilkannya.
  Future<void> signInWith(String email, String password) async {
    await signIn.login(email, password);
    // Mode demo tidak memuat profil dari server.
    if (DemoMode.active) {
      _set(SessionStatus.ready);
      return;
    }
    await _loadProfile();
  }

  Future<void> refreshProfile() {
    if (DemoMode.active) return Future.value();
    return _loadProfile();
  }

  Future<void> signOut() async {
    await signIn.logout();
    _profile = null;
    _set(SessionStatus.signedOut);
  }

  Future<void> _loadProfile() async {
    final api = profileApi;
    if (api == null) {
      _set(SessionStatus.ready);
      return;
    }
    try {
      final me = await api.me().timeout(_stepTimeout);
      _profile = me;
      _roles = await _ambilPeran();
      _error = null;
      _set(me.profileCompleted ? SessionStatus.ready : SessionStatus.profileIncomplete);
    } on ProfileException catch (e) {
      _error = e.message;
      _set(SessionStatus.signedOut);
    } on TimeoutException {
      _error = 'Server belum merespons. Periksa jaringan lalu coba lagi.';
      _set(SessionStatus.signedOut);
    } catch (_) {
      _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.';
      _set(SessionStatus.signedOut);
    }
  }

  /// Peran hanya untuk tampilan. Kalau gagal dimuat, halaman tetap berjalan tanpa peran.
  Future<List<String>> _ambilPeran() async {
    final ambil = loadRoles;
    if (ambil == null) return const [];
    try {
      return await ambil();
    } catch (_) {
      return const [];
    }
  }

  void _set(SessionStatus next) {
    _status = next;
    notifyListeners();
  }
}
