import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/auth/login_page.dart';

Future<void> _submit(WidgetTester tester, {required String email, required String password}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Kata sandi'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tombol masuk meneruskan email dan kata sandi', (tester) async {
    String? gotEmail;
    String? gotPassword;
    await tester.pumpWidget(MaterialApp(
      home: LoginPage(onLogin: (email, password) async {
        gotEmail = email;
        gotPassword = password;
      }),
    ));

    await _submit(tester, email: 'user@example.com', password: 'rahasia123');

    expect(gotEmail, 'user@example.com');
    expect(gotPassword, 'rahasia123');
  });

  testWidgets('menampilkan pesan gagal bila login error', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LoginPage(onLogin: (_, _) async => throw Exception('gagal')),
    ));

    await _submit(tester, email: 'user@example.com', password: 'salah');

    expect(find.text('Masuk gagal. Coba lagi beberapa saat.'), findsOneWidget);
  });

  testWidgets('menampilkan pesan akses bila akun belum punya role', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LoginPage(onLogin: (_, _) async => throw StateError('Akun belum memiliki akses. Hubungi admin.')),
    ));

    await _submit(tester, email: 'user@example.com', password: 'rahasia123');

    expect(find.text('Akun belum memiliki akses. Hubungi admin.'), findsOneWidget);
  });

  testWidgets('kredensial salah dari Firebase menampilkan pesan kata sandi salah', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LoginPage(
        onLogin: (_, _) async => throw FirebaseAuthException(code: 'invalid-credential'),
      ),
    ));

    await _submit(tester, email: 'user@example.com', password: 'salah');

    expect(find.text('Email atau kata sandi salah.'), findsOneWidget);
  });

  testWidgets('akun dinonaktifkan dari Firebase menampilkan pesan yang sesuai', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LoginPage(
        onLogin: (_, _) async => throw FirebaseAuthException(code: 'user-disabled'),
      ),
    ));

    await _submit(tester, email: 'user@example.com', password: 'rahasia123');

    expect(find.text('Akun dinonaktifkan. Hubungi admin.'), findsOneWidget);
  });

  testWidgets('email tidak valid tidak memanggil login', (tester) async {
    var called = 0;
    await tester.pumpWidget(MaterialApp(
      home: LoginPage(onLogin: (_, _) async => called++),
    ));

    await _submit(tester, email: 'bukan-email', password: 'rahasia123');

    expect(called, 0);
    expect(find.text('Masukkan email yang valid'), findsOneWidget);
  });
}
