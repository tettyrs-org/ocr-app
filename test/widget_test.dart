import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/features/auth/login_page.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('halaman login menampilkan form email dan kata sandi', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LoginPage(onLogin: (_, _) async {})));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Kata sandi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
  });
}
