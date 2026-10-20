import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Berkas dari input file browser: nama dan isinya.
class WebPickedFile {
  WebPickedFile({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

/// Memilih berkas lewat `<input type="file">` bawaan browser. Tidak memakai plugin, sehingga tidak
/// bergantung pada registrasi plugin web. `preferCamera` meminta kamera belakang di perangkat mobile.
/// Mengembalikan null bila pengguna membatalkan.
Future<WebPickedFile?> pickWithBrowserInput({required String accept, bool preferCamera = false}) {
  final completer = Completer<WebPickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  if (preferCamera) {
    input.setAttribute('capture', 'environment');
  }

  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onloadend = ((web.Event _) {
      final result = reader.result;
      if (result == null || completer.isCompleted) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final buffer = (result as JSArrayBuffer).toDart;
      completer.complete(WebPickedFile(bytes: buffer.asUint8List(), name: file.name));
    }).toJS;
    reader.onerror = ((web.Event _) {
      if (!completer.isCompleted) completer.completeError(StateError('Berkas tidak bisa dibaca'));
    }).toJS;
    reader.readAsArrayBuffer(file);
  }).toJS;

  input.click();
  return completer.future;
}
