// Server BFF uji lokal. Menjalankan handler yang SAMA dengan Cloud Function (index.js) di Node, sehingga
// alur sesi, CSRF, dan penerusan ke API diuji tanpa menyentuh produksi.
//
// Jalur:  aplikasi / browser -> quick tunnel -> server ini (port 8090) -> API lokal (API_BASE)
// Jangan dipakai untuk produksi. Konfigurasi dibaca dari environment (lihat deploy/test/start-test-tunnel.ps1).
import http from 'node:http';
import handler from './src/index.js';
import { handleAdmin } from './src/admin.js';

const PORT = Number(process.env.TEST_BFF_PORT || 8090);

const env = {
  API_BASE: process.env.API_BASE || 'http://localhost:8081',
  COOKIE_KEY: process.env.COOKIE_KEY,
  APP_ORIGIN: process.env.APP_ORIGIN || 'http://localhost:5000',
  APP_ORIGIN_ALT: process.env.APP_ORIGIN_ALT || 'http://localhost:5000',
  ADMIN_APP_ORIGIN: process.env.ADMIN_APP_ORIGIN || 'http://localhost:5001',
  FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID || 'YOUR_FIREBASE_PROJECT_ID',
  WEB_API_KEY: process.env.WEB_API_KEY || '',
  RESEND_API_KEY: process.env.RESEND_API_KEY || '',
  MAIL_FROM: process.env.MAIL_FROM || '',
};

if (!env.COOKIE_KEY) {
  console.error('COOKIE_KEY wajib diisi (32 byte base64url, khusus uji)');
  process.exit(1);
}

async function toRequest(req) {
  const url = `http://localhost:${PORT}${req.url}`;
  const chunks = [];
  for await (const c of req) chunks.push(c);
  const body = chunks.length ? Buffer.concat(chunks) : undefined;
  return new Request(url, { method: req.method, headers: req.headers, body, duplex: 'half' });
}

async function send(res, response) {
  res.statusCode = response.status;
  response.headers.forEach((value, key) => res.setHeader(key, value));
  const buf = Buffer.from(await response.arrayBuffer());
  res.end(buf);
}

http
  .createServer(async (req, res) => {
    try {
      const request = await toRequest(req);
      const path = new URL(request.url).pathname;
      const response = path.startsWith('/admin/api')
        ? await handleAdmin(request, env)
        : await handler.fetch(request, env);
      await send(res, response);
    } catch (err) {
      console.error('kesalahan server uji:', err?.message);
      res.statusCode = 500;
      res.end('{"error":{"code":"INTERNAL_ERROR","message":"Terjadi kesalahan di server uji"}}');
    }
  })
  .listen(PORT, () => console.log(`BFF uji berjalan di http://localhost:${PORT}`));
