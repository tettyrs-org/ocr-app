import 'dart:js_interop';

@JS('demoFlag.get')
external bool _flagAda();

@JS('demoFlag.set')
external void _flagSet(bool aktif);

/// Apakah sesi sebelumnya (tab yang sama) berada di mode demo. Hanya penanda, bukan data.
bool flagDemoTersimpan() {
  try {
    return _flagAda();
  } catch (_) {
    return false;
  }
}

void simpanFlagDemo(bool aktif) {
  try {
    _flagSet(aktif);
  } catch (_) {
    // Tidak tersedia: demo tidak dipulihkan saat refresh.
  }
}
