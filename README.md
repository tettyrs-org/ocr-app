# OCR Documents — app (Flutter)

Web and mobile app for uploading travel-expense documents and identity cards (KTP), following the
OCR progress, and reviewing and saving the extracted data. Built with Flutter. The server side is a
Cloud Functions backend-for-frontend (BFF) in front of a Quarkus API.

## Features

- **Document list** with status, type, and upload time (WIB, UTC+7).
- **Upload** from a file or the camera (web), in three categories: identity card (KTP), travel
  expense documents (fuel receipt, assignment letter, travel order, receipt), and other. Photos are
  checked for quality before upload, and the app shows tips when a photo is blurry or too dark.
- **Processing status** with polling. The page moves to the review screen as soon as the result is
  ready.
- **Review and correction.** Each field shows the OCR value, its original text, and a marker when
  confidence is low or when a value was filled in by the vision companion. Saved documents cannot
  be changed.
- **Accounts and sessions.** Sign-in uses Firebase Authentication. The session is kept in an
  HttpOnly cookie set by the BFF, so no token is stored in the browser.

## Structure

```
lib/
  auth/            session, BFF client, storage (web and native)
  features/        documents, auth, account, profile, invitation, reset
  layouts/         navigation shell
  router/          go_router
  theme/, widgets/ shared UI
functions/         Cloud Functions: BFF (/bff/**) and admin endpoints
test/              Flutter widget and unit tests
web/               web entry point
```

Firebase Hosting has two targets: `app` (this app) and `admin` (a separately deployed web app).

## Getting started

Requirements: stable Flutter, the Firebase CLI, and Node.js for the Cloud Functions.

1. **Firebase configuration.** Run `flutterfire configure` to generate your own
   `lib/firebase_options.dart` and platform files. The files in this repository contain placeholders.
2. **Local configuration.** Copy `.env.example` to `.env` and set `BFF_BASE_URL`. Copy
   `functions/.env.example` to `functions/.env` and fill in the values. Do not commit `.env` files.
3. **Run locally:**

   ```bash
   flutter pub get
   flutter run -d chrome --dart-define=BFF_BASE_URL=<bff-url>
   ```

4. **Build the web app for hosting:**

   ```bash
   flutter build web --release --pwa-strategy=none --dart-define=BFF_BASE_URL=<bff-url>
   firebase deploy --only hosting:app
   ```

   `build-web.ps1` (Windows) reads `.env` and passes its values as `--dart-define` arguments.

## Cloud Functions (BFF)

```bash
cd functions
npm install
npm test          # node --test
firebase deploy --only functions
```

The BFF forwards `/bff/**` requests to the API at `API_BASE`, verifies Firebase ID tokens, and
manages the session cookie. Secrets (cookie key, mail API key) are stored in Secret Manager, not in
files.

## Tests

```bash
flutter test
```

Tests use fictional data and do not need any production service.

## Security

- Do not commit `.env`, `functions/.env`, `google-services.json`, `GoogleService-Info.plist`, or a
  `.firebaserc` with real values.
- Personal data is not stored in the app. KTP data is shown only to its owner, after the API decrypts it.

## License

Not yet determined.
