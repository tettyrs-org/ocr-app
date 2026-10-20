import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

/// Halaman reset sandi dari tautan email (`/reset?oobCode=...`).
///
/// Dikirim oleh Firebase Authentication ketika admin meminta reset. Sandi baru dimasukkan langsung oleh pegawai
/// dan dipasang ke Firebase lewat SDK. Aplikasi dan admin tidak pernah melihat sandi itu.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.oobCode});

  final String? oobCode;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _email;
  bool _checking = true;
  bool _busy = false;
  bool _done = false;
  String? _error;

  static const _invalid = 'Tautan reset tidak valid atau sudah kedaluwarsa. Minta admin mengirim ulang email reset.';

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = widget.oobCode;
    if (code == null || code.isEmpty) {
      setState(() {
        _checking = false;
        _error = _invalid;
      });
      return;
    }
    try {
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(code);
      if (mounted) setState(() => _email = email);
    } on FirebaseAuthException catch (e) {
      debugPrint('verifikasi reset gagal: ${e.code}');
      if (mounted) setState(() => _error = _invalid);
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode!,
        newPassword: _password.text,
      );
      if (mounted) setState(() => _done = true);
    } on FirebaseAuthException catch (e) {
      debugPrint('konfirmasi reset gagal: ${e.code}');
      if (mounted) {
        setState(() => _error = e.code == 'weak-password'
            ? 'Sandi terlalu lemah. Gunakan minimal 8 karakter dengan huruf dan angka.'
            : _invalid);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Tidak ada koneksi. Periksa jaringan lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _passwordError(String v) {
    if (v.length < 8) return 'Sandi minimal 8 karakter';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Sandi harus memuat huruf dan angka';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Atur ulang sandi')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _checking
                  ? const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _done
                      ? _doneView()
                      : _email == null
                          ? _invalidView()
                          : _formView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _invalidView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error ?? _invalid, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _doneView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sandi Anda sudah diatur ulang. Silakan masuk dengan sandi baru.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.heading, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton(onPressed: () => context.go('/login'), child: const Text('Masuk')),
        ),
      ],
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Akun: $_email', style: const TextStyle(color: AppColors.text)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Sandi baru'),
            validator: (v) => _passwordError(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Ulangi sandi baru'),
            validator: (v) => v != _password.text ? 'Sandi tidak sama' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Menyimpan...' : 'Simpan sandi baru'),
            ),
          ),
        ],
      ),
    );
  }
}
