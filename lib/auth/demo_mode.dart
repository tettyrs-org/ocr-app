/// Email khusus untuk mode demo di halaman login. Tidak ada permintaan ke Firebase Auth, BFF, API, atau database.
const kDemoEmail = 'demo@ocr.local';

/// Status mode demo untuk sesi ini. Di-reset saat halaman dimuat ulang.
class DemoMode {
  DemoMode._();

  static bool active = false;
}
