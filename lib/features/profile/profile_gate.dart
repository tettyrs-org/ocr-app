import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'profile_api.dart';

/// Menahan akses ke aplikasi sampai profil pegawai lengkap (api-spec.md bagian 12).
/// Pegawai undangan mengisi nama dan NIP di sini; setelah diterima, [builder] ditampilkan.
class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.api,
    required this.onLogout,
    required this.builder,
  });

  final ProfileApi api;
  final VoidCallback onLogout;
  final WidgetBuilder builder;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  MeProfile? _me;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await widget.api.me();
      if (mounted) setState(() => _me = me);
    } on ProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    if (_loading && me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (me == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Profil tidak dapat dimuat.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
              ],
            ),
          ),
        ),
      );
    }
    if (me.profileCompleted) return widget.builder(context);
    return ProfileCompletePage(
      api: widget.api,
      email: me.email,
      onCompleted: (updated) => setState(() => _me = updated),
      onLogout: widget.onLogout,
    );
  }
}

/// Formulir profil: nama lengkap dan NIP. Keduanya dicocokkan dengan data kepegawaian oleh server.
class ProfileCompletePage extends StatefulWidget {
  const ProfileCompletePage({
    super.key,
    required this.api,
    required this.email,
    required this.onCompleted,
    required this.onLogout,
  });

  final ProfileApi api;
  final String email;
  final ValueChanged<MeProfile> onCompleted;
  final VoidCallback onLogout;

  @override
  State<ProfileCompletePage> createState() => _ProfileCompletePageState();
}

class _ProfileCompletePageState extends State<ProfileCompletePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nip = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _nip.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await widget.api.complete(fullName: _name.text.trim(), nip: _nip.text.trim());
      if (mounted) widget.onCompleted(profile);
    } on ProfileException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lengkapi profil'),
        actions: [
          IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout), tooltip: 'Keluar'),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Selamat datang, ${widget.email}',
                      style: const TextStyle(color: AppColors.heading, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Isi nama lengkap dan NIP sesuai data kepegawaian Anda. Setelah disimpan, Anda bisa mengunggah dokumen.',
                      style: TextStyle(color: AppColors.text, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nama lengkap'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 3) return 'Nama lengkap wajib diisi (minimal 3 karakter)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nip,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'NIP (18 digit)'),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (!RegExp(r'^\d{18}$').hasMatch(t)) return 'NIP harus 18 digit angka';
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Menyimpan...' : 'Simpan dan lanjutkan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
