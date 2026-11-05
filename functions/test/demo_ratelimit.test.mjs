// Batas unggahan demo per IP. Memakai CF-Connecting-IP (diset Cloudflare) sebagai alamat klien.
// Dijalankan dengan `npm test`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleDemoExtract } from '../src/demo.js';

function permintaan(ip) {
  return new Request('https://example.test/bff/demo/extract', {
    method: 'POST',
    headers: {
      'content-type': 'application/octet-stream',
      'x-category': 'auto',
      'cf-connecting-ip': ip,
    },
    body: new Uint8Array([1, 2, 3]),
  });
}

// Tanpa DEMO_OCR_BASE, permintaan yang lolos batas dijawab 503. Jadi status 429 berarti batas tercapai.
const env = {};

test('IP yang sama terkena batas setelah 30 permintaan', async () => {
  const ip = '198.51.100.7';
  let kena = 0;
  for (let i = 0; i < 31; i += 1) {
    const res = await handleDemoExtract(permintaan(ip), env);
    if (res.status === 429) kena += 1;
  }
  assert.equal(kena, 1, 'permintaan ke-31 harus ditolak');
});

test('IP lain tidak ikut terkena batas IP pertama', async () => {
  const res = await handleDemoExtract(permintaan('203.0.113.99'), env);
  assert.notEqual(res.status, 429);
});
