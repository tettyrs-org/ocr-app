import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'document_status.dart';
import 'document_status_chip.dart';
import 'documents_api.dart';

/// S8: status pemrosesan. Polling mengikuti `poll_after_ms` dan berhenti saat status bukan `processing`.
class ProcessingPage extends StatefulWidget {
  const ProcessingPage({
    super.key,
    required this.api,
    required this.documentId,
    required this.docRef,
    required this.pollAfterMs,
  });

  final DocumentsApi api;
  final String documentId;
  final String docRef;
  final int pollAfterMs;

  @override
  State<ProcessingPage> createState() => _ProcessingPageState();
}

class _ProcessingPageState extends State<ProcessingPage> {
  // Batas tampilan "masih diproses" (design.md 3.2). Polling tetap berjalan sampai status berubah atau layar ditutup.
  static const _longWait = Duration(minutes: 2);

  Timer? _timer;
  DocumentStatus _status = DocumentStatus.processing;
  String? _error;
  final _started = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _schedule();
    // Memperbarui tampilan langkah dan pesan waktu tunggu setiap detik.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: widget.pollAfterMs), _poll);
  }

  Future<void> _poll() async {
    try {
      final result = await widget.api.status(widget.documentId);
      if (!mounted) return;
      setState(() {
        _status = result.status;
        _error = null;
      });
      if (_status == DocumentStatus.processing) _schedule();
      // Hasil ekstraksi sudah siap untuk ditinjau: langsung ke halaman tinjau, tidak perlu kembali ke daftar dulu.
      if (_status == DocumentStatus.extracted) {
        _timer?.cancel();
        context.pushReplacement('/dokumen/${widget.documentId}/tinjau');
      }
    } on DocumentsApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _schedule();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Koneksi terputus. Status akan diperbarui saat jaringan kembali.');
      _schedule();
    }
  }

  // Langkah yang ditampilkan. Waktu tiap langkah hanya perkiraan untuk tampilan, bukan status server.
  static const _steps = ['Membaca teks dokumen', 'Mengenali isian', 'Menyusun data untuk ditinjau'];

  int get _stepIndex {
    final elapsed = DateTime.now().difference(_started);
    if (elapsed < const Duration(seconds: 5)) return 0;
    if (elapsed < const Duration(seconds: 15)) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final waitedLong = DateTime.now().difference(_started) > _longWait;
    final processing = _status == DocumentStatus.processing;
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.docRef),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Kembali ke daftar',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: Column(
                  children: [
                    if (processing) ...[
                      Text('Sedang membaca dokumen', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        waitedLong
                            ? 'Masih diproses. Anda bisa kembali nanti. Dokumen tetap tersimpan.'
                            : 'Biasanya selesai dalam beberapa detik. Halaman ini diperbarui otomatis.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: const LinearProgressIndicator(minHeight: 4),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      for (var i = 0; i < _steps.length; i++)
                        _StepRow(
                          label: _steps[i],
                          state: i < _stepIndex
                              ? _StepState.done
                              : i == _stepIndex
                                  ? _StepState.current
                                  : _StepState.pending,
                        ),
                    ] else ...[
                      Icon(
                        _status == DocumentStatus.extractionFailed
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 40,
                        color: _status == DocumentStatus.extractionFailed ? AppColors.error : AppColors.teal,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      Text(_resultText(_status), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: AppSpace.md),
                    DocumentStatusChip(status: _status),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AppBanner(message: _error!, tone: AppBannerTone.warning),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Kembali ke daftar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resultText(DocumentStatus status) {
    return switch (status) {
      DocumentStatus.extracted => 'Dokumen selesai diproses dan perlu ditinjau. Buka daftar untuk meninjau hasilnya.',
      DocumentStatus.verified => 'Dokumen sudah tersimpan.',
      DocumentStatus.extractionFailed => 'Dokumen belum bisa dibaca. Coba unggah ulang dengan foto yang lebih jelas.',
      _ => 'Status dokumen tidak dikenal. Buka daftar untuk melihat detailnya.',
    };
  }
}

enum _StepState { done, current, pending }

/// Satu baris langkah pemrosesan: tanda selesai, sedang berjalan, atau menunggu.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.teal,
      _StepState.current => AppColors.heading,
      _StepState.pending => AppColors.slate,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: state == _StepState.current
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                    state == _StepState.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: color,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: state == _StepState.current ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
