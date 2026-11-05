// Cloud Functions untuk OCR. Logika ada di src/.
// bff       : BFF aplikasi utama, dipasang di Hosting site "app" lewat rewrite /bff/**
// adminBff  : BFF aplikasi admin, dipasang di Hosting site "admin" lewat rewrite /admin/api/**
// Kontrak: documents/tech/web-bff.md, admin-bff.md, auth-firebase.md
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import handler from './src/index.js';
import { handleAdmin } from './src/admin.js';

// Nilai non-rahasia dibaca dari functions/.env saat deploy (lihat start-quick-tunnel.ps1)
const APP_ORIGIN = defineString('APP_ORIGIN');
const ADMIN_APP_ORIGIN = defineString('ADMIN_APP_ORIGIN', { default: 'https://admin-ocr-wjv.web.app' });
const OCR_PROJECT_ID = defineString('OCR_PROJECT_ID', { default: 'ocr-wjv-b56b7' });
const API_BASE = defineString('API_BASE');
// Mode demo: ms-ocr (tanpa database) lewat tunnel terpisah. Token disimpan sebagai secret.
const DEMO_OCR_BASE = defineString('DEMO_OCR_BASE', { default: '' });
const DEMO_OCR_TOKEN = defineSecret('DEMO_OCR_TOKEN');
// Kunci web publik (sama dengan firebase_options). Dipakai untuk accounts:sendOobCode (undangan).
const WEB_API_KEY = defineString('WEB_API_KEY');

// Rahasia disimpan di Secret Manager: firebase functions:secrets:set <NAMA>
const COOKIE_KEY = defineSecret('COOKIE_KEY');
// Email undangan dan reset (src/mail.js). Kunci API disimpan di Secret Manager.
const RESEND_API_KEY = defineSecret('RESEND_API_KEY');
const MAIL_FROM = defineString('MAIL_FROM');

// Header yang dibutuhkan handler. Header lain (termasuk host) sengaja tidak diteruskan.
const FORWARDED_HEADERS = ['origin', 'cookie', 'content-type', 'authorization', 'x-csrf-token', 'idempotency-key', 'traceparent', 'x-category', 'x-forwarded-for'];

// Header hop-by-hop dan panjang body dibuat ulang oleh Express, jangan diteruskan dari upstream.
const SKIP_RESPONSE_HEADERS = new Set(['set-cookie', 'transfer-encoding', 'connection', 'keep-alive', 'content-length', 'content-encoding']);

function buildRequest(req) {
  const headers = new Headers();
  for (const name of FORWARDED_HEADERS) {
    const v = req.headers[name];
    if (v) headers.set(name, Array.isArray(v) ? v.join(', ') : v);
  }
  const init = { method: req.method, headers };
  if (req.method !== 'GET' && req.method !== 'HEAD') init.body = req.rawBody;
  return new Request(`https://${req.headers.host}${req.originalUrl}`, init);
}

async function sendResponse(res, response) {
  res.status(response.status);
  response.headers.forEach((value, key) => {
    if (!SKIP_RESPONSE_HEADERS.has(key.toLowerCase())) res.append(key, value);
  });
  for (const cookie of response.headers.getSetCookie()) res.append('Set-Cookie', cookie);
  res.send(Buffer.from(await response.arrayBuffer()));
}

// timeoutSeconds 120: KTP dengan pendamping vision bisa lebih dari 60 detik (demo).
export const bff = onRequest({ region: 'asia-southeast2', secrets: [COOKIE_KEY, DEMO_OCR_TOKEN], timeoutSeconds: 120 }, async (req, res) => {
  const env = {
    APP_ORIGIN: APP_ORIGIN.value(),
    // Domain situs hosting utama. Action URL reset sandi memakai alamat ini (lihat auth-firebase.md bagian 8).
    APP_ORIGIN_ALT: 'https://ocr-wjv-b56b7.web.app',
    FIREBASE_PROJECT_ID: OCR_PROJECT_ID.value(),
    COOKIE_KEY: COOKIE_KEY.value(),
    API_BASE: API_BASE.value(),
    DEMO_OCR_BASE: DEMO_OCR_BASE.value(),
    DEMO_OCR_TOKEN: DEMO_OCR_TOKEN.value(),
  };
  await sendResponse(res, await handler.fetch(buildRequest(req), env));
});

export const adminBff = onRequest({ region: 'asia-southeast2', secrets: [COOKIE_KEY, RESEND_API_KEY] }, async (req, res) => {
  const env = {
    ADMIN_APP_ORIGIN: ADMIN_APP_ORIGIN.value(),
    APP_ORIGIN: APP_ORIGIN.value(),
    FIREBASE_PROJECT_ID: OCR_PROJECT_ID.value(),
    COOKIE_KEY: COOKIE_KEY.value(),
    API_BASE: API_BASE.value(),
    WEB_API_KEY: WEB_API_KEY.value(),
    RESEND_API_KEY: RESEND_API_KEY.value(),
    MAIL_FROM: MAIL_FROM.value(),
  };
  await sendResponse(res, await handleAdmin(buildRequest(req), env));
});
