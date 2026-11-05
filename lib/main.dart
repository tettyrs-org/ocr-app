import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'auth/app_session.dart';
import 'auth/bff_service.dart';
import 'auth/demo_sign_in.dart';
import 'auth/sign_in.dart';
import 'features/documents/demo_documents_api.dart';
import 'features/profile/profile_api.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

// Kosong berarti satu origin dengan aplikasi (Firebase Hosting melayani /bff/* lewat Cloud Function).
const _bffBaseUrl = String.fromEnvironment('BFF_BASE_URL', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // URL tanpa '#': reload di halaman mana pun kembali ke halaman itu (lihat router/app_router.dart).
    usePathUrlStrategy();
  }
  // Web dan mobile memakai identitas Firebase yang sama (documents/tech/auth-firebase.md).
  await Firebase.initializeApp(
    options: kIsWeb ? DefaultFirebaseOptions.web : DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OcrApp());
}

Future<SignInController> _defaultSignIn() async {
  // Di web, sesi BFF memakai cookie. Di mobile, setiap permintaan membawa ID token Firebase terbaru.
  final bff = BffService(
    baseUrl: _bffBaseUrl,
    idTokenProvider: kIsWeb ? null : _idTokenTerbaru,
  );
  return DemoAwareSignIn(FirebaseSignIn(bff));
}

/// ID token Firebase berlaku 1 jam. `getIdToken()` memperbaruinya bila sudah kedaluwarsa.
Future<String?> _idTokenTerbaru() async => FirebaseAuth.instance.currentUser?.getIdToken();

class OcrApp extends StatefulWidget {
  const OcrApp({super.key, this.signInFactory});

  final Future<SignInController> Function()? signInFactory;

  @override
  State<OcrApp> createState() => _OcrAppState();
}

class _OcrAppState extends State<OcrApp> {
  AppSession? _session;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final signIn = await (widget.signInFactory ?? _defaultSignIn)();
    final inner = signIn is DemoAwareSignIn ? signIn.inner : signIn;
    final bff = inner is FirebaseSignIn ? inner.service : BffService(baseUrl: _bffBaseUrl);
    final profileApi = inner is FirebaseSignIn ? ProfileApi(bff) : null;
    final session = AppSession(
      signIn: signIn,
      profileApi: profileApi,
      loadRoles: profileApi == null ? null : () async => (await bff.currentUser())?.roles ?? const <String>[],
    );
    final router = buildAppRouter(
      session: session,
      documents: DemoAwareDocumentsApi(bff),
      profiles: profileApi,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      _router = router;
    });
    // Pemulihan sesi dijalankan setelah router siap, agar redirect memakai status yang benar.
    await session.start();
  }

  @override
  void dispose() {
    _router?.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router;
    if (router == null) {
      return MaterialApp(
        title: 'OCR Dokumen',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp.router(
      title: 'OCR Dokumen',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // Selama sesi dipulihkan, halaman tidak dibangun (agar tidak memanggil API tanpa sesi). URL tetap.
      builder: (context, child) => ListenableBuilder(
        listenable: _session!,
        builder: (context, _) => _session!.status == SessionStatus.loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : child!,
      ),
    );
  }
}
