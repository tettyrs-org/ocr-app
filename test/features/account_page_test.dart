import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/auth/demo_mode.dart';
import 'package:ocr_app/features/account/account_page.dart';

void main() {
  setUp(() => DemoMode.active = false);
  tearDown(() => DemoMode.active = false);

  Widget buat(Future<void> Function() onLogout) => MaterialApp(
        home: AccountPage(profile: null, onLogout: onLogout),
      );

  testWidgets('mode demo menampilkan label dan tombol keluar dari demo', (tester) async {
    DemoMode.active = true;
    await tester.pumpWidget(buat(() async {}));

    expect(find.text('Mode demo'), findsOneWidget);
    expect(find.text('Keluar dari demo'), findsOneWidget);
  });

  testWidgets('keluar meminta konfirmasi dan batal tidak memanggil onLogout', (tester) async {
    var keluar = 0;
    await tester.pumpWidget(buat(() async => keluar++));

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(keluar, 0);
  });

  testWidgets('peran ditampilkan dengan label yang mudah dibaca', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AccountPage(profile: null, roles: const ['ADMIN', 'USER'], onLogout: () async {}),
    ));

    expect(find.text('Peran: Admin, Pengguna'), findsOneWidget);
  });

  testWidgets('konfirmasi keluar memanggil onLogout sekali', (tester) async {
    var keluar = 0;
    await tester.pumpWidget(buat(() async => keluar++));

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(keluar, 1);
  });
}
