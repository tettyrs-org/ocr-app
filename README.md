# OCR app

Flutter web app for uploading and reviewing travel and reimbursement documents (ID cards, fuel receipts, surat tugas, SPD). It talks to the backend only through a Backend-for-Frontend (BFF) that lives in `pages/` (Cloudflare Pages) and `functions/` (shared handler code).

## Layout

| Path | What it is |
|---|---|
| `lib/` | Flutter app: features (documents, account, profile), auth, layouts, theme |
| `pages/` | Cloudflare Pages entry (`_worker.js`) and `wrangler.toml`. Routes `/bff/*` to the BFF, everything else to static assets |
| `functions/` | BFF handler code (`src/`), shared by the Pages worker and the legacy Firebase Functions target |
| `web/` | Web shell (`index.html`, `demo_flag.js`, service-worker cleanup) |
| `test/` | Flutter tests |
| `build-web.ps1` | Release build with the values from `.env` as `--dart-define` |
| `firebase.json` | Legacy Firebase Hosting targets (`app`, `admin`) |

## Requirements

- Flutter SDK with Dart `^3.10.7` (see `pubspec.yaml`)
- PowerShell for `build-web.ps1`
- Node 22 and wrangler, only when deploying to Cloudflare Pages

## Configuration

`app/.env` holds build-time values. The only key today is `BFF_BASE_URL`, the base URL the app calls for `/bff/*`. Do not commit real values.

## Run and build

```bash
flutter pub get
flutter run -d chrome          # development; BFF_BASE_URL must point to a running BFF
flutter test
```

```powershell
powershell -ExecutionPolicy Bypass -File app\build-web.ps1   # release build into build/web
```

The release build disables the service worker (`--pwa-strategy=none`), so the app has no offline mode.

## Deploy

The current target is Cloudflare Pages project `ocr-platform-app`. `build/web` must also contain the bundled `_worker.js`, otherwise `/bff/*` is not served. See `deploy/pages/README.md` for the startup script that connects Pages to the backend through quick tunnels, and `deploy/README.md` for the environments.

## Related projects

- [ocr-api](https://github.com/tettyrs-org/ocr-api) - Public API and document lifecycle (verifies Firebase ID tokens)
- [ms-ocr](https://github.com/tettyrs-org/ms-ocr) - Java extraction and correction service
- [ocr-engine](https://github.com/tettyrs-org/ocr-engine) - Python OCR service (Tesseract, optional vision companion)
- [ocr-documents](https://github.com/tettyrs-org/ocr-documents) - Architecture, API specification, and deployment docs (private)

## Known limitations

Listed openly so they are not mistaken for solved problems:

- **Demo mode keeps results only in memory.** Nothing is saved to a database. The demo flag is kept in `sessionStorage`, so a reload stays in demo mode but closing the tab ends it.
- **Demo limits.** Uploads are capped at 10 MB, and each IP can send 30 demo requests per 10 minutes. Replace, delete, verify, and template actions are blocked in demo mode.
- **Firebase Hosting and Cloud Functions cannot be deployed right now.** Blaze billing is disabled for project `ocr-wjv-b56b7`, so the Pages path is used instead.
- **Admin operations need a service account key.** The organization policy `iam.disableServiceAccountKeyCreation` blocks creating that key, so admin operations are not available until an administrator changes the policy.
- **Backend addresses change.** Quick tunnels get a new URL each time they start. `deploy/pages/start-backend-tunnels.ps1` updates the Pages secrets and redeploys.
- **Content Security Policy is strict.** `firebase.json` and `web/_headers` allow only specific script, connect, and font sources. A new external CDN or API domain needs a CSP change first, or the browser blocks it.
- **Identity extraction is slow on CPU.** A KTP can take 15 to 40 seconds because vision runs on the engine's CPU. The review screen shows progress while it runs.
