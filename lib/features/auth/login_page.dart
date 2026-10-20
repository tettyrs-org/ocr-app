import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

/// Halaman masuk. Tidak ada pendaftaran: akun dibuat oleh admin.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});

  final Future<void> Function(String email, String password) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogin(_email.text.trim(), _password.text);
    } catch (e) {
      debugPrint('Login gagal: $e');
      if (mounted) {
        setState(() => _error = _messageFor(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'invalid-email':
        case 'wrong-password':
        case 'user-not-found':
          return 'Email atau kata sandi salah.';
        case 'user-disabled':
          return 'Akun dinonaktifkan. Hubungi admin.';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan. Coba lagi beberapa menit lagi.';
        case 'network-request-failed':
          return 'Tidak ada koneksi internet. Coba lagi.';
      }
    }
    if (e is StateError && e.message.contains('Akun belum memiliki akses')) {
      return 'Akun belum memiliki akses. Hubungi admin.';
    }
    return 'Masuk gagal. Coba lagi beberapa saat.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.document_scanner_outlined, color: AppColors.surface, size: 32),
                    ),
                    const SizedBox(height: 24),
                    Text('OCR Dokumen', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    const Text(
                      'Masuk untuk mengunggah dan meninjau dokumen Anda.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Masukkan email yang valid' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Kata sandi'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Kata sandi wajib diisi' : null,
                      onFieldSubmitted: (_) => _busy ? null : _login(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _busy ? null : _login,
                        child: Text(_busy ? 'Memproses...' : 'Masuk'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Akun dibuat oleh admin. Hubungi admin jika belum punya akun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.slate, fontSize: 12),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      AppBanner(message: _error!),
                    ],
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
