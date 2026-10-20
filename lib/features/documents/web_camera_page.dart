import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../theme/app_theme.dart';

/// S5 di web: kamera dalam aplikasi (getUserMedia), dengan bingkai panduan dan tombol ambil.
/// Berfungsi di laptop dengan webcam dan di browser HP (kamera belakang bila tersedia).
class WebCameraPage extends StatefulWidget {
  const WebCameraPage({super.key});

  @override
  State<WebCameraPage> createState() => _WebCameraPageState();
}

class _WebCameraPageState extends State<WebCameraPage> {
  static int _counter = 0;

  late final String _viewType;
  final web.HTMLVideoElement _video = web.HTMLVideoElement();
  web.MediaStream? _stream;
  bool _ready = false;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _viewType = 'ocr-camera-${_counter++}';
    _video
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', '');
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _video);
    _start();
  }

  Future<void> _start() async {
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(
            video: {'facingMode': 'environment'}.jsify()!,
          ))
          .toDart;
      _stream = stream;
      _video.srcObject = stream;
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kamera tidak dapat dibuka. Izinkan akses kamera di browser, atau pilih berkas.');
      }
    }
  }

  /// Mengambil satu frame dari video sebagai JPEG.
  Future<Uint8List> _snapshot() {
    final completer = Completer<Uint8List>();
    final canvas = web.HTMLCanvasElement()
      ..width = _video.videoWidth
      ..height = _video.videoHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(_video, 0, 0);
    canvas.toBlob(((web.Blob? blob) {
      if (blob == null) {
        completer.completeError(StateError('Gagal mengambil gambar'));
        return;
      }
      blob.arrayBuffer().toDart.then(
        (buffer) => completer.complete(buffer.toDart.asUint8List()),
        onError: (Object e) => completer.completeError(e),
      );
    }).toJS, 'image/jpeg', 0.92.toJS);
    return completer.future;
  }

  Future<void> _capture() async {
    if (!_ready || _capturing) return;
    setState(() => _capturing = true);
    try {
      final bytes = await _snapshot();
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = 'Foto gagal diambil. Coba lagi.';
        });
      }
    }
  }

  @override
  void dispose() {
    final tracks = _stream?.getTracks().toDart ?? const <web.MediaStreamTrack>[];
    for (final track in tracks) {
      track.stop();
    }
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ambil foto'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_error == null)
                    SizedBox.expand(child: HtmlElementView(viewType: _viewType))
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  // Bingkai panduan dokumen
                  if (_error == null)
                    IgnorePointer(
                      child: FractionallySizedBox(
                        widthFactor: 0.82,
                        heightFactor: 0.72,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 2),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Letakkan dokumen di dalam bingkai, pastikan tidak buram.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: 'Ambil foto',
                    child: GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ready ? Colors.white : Colors.white24,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: _capturing
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(strokeWidth: 3),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
