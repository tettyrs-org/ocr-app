// Mode demo: ekstraksi tanpa login dan tanpa database.
// Berkas diteruskan ke ms-ocr (/demo/extract) yang hanya membaca dan mengembalikan JSON.
// Tidak ada sesi, tidak ada penulisan, dan tidak ada akses ke API atau database.

const MAX_BYTES = 10 * 1024 * 1024;
const KATEGORI = new Set(['auto', 'identity', 'reimburse', 'other']);
// Batas per IP: 30 unggahan per 10 menit. Disimpan di memori tiap instance (tidak ada database).
// Ini pengaman sederhana terhadap pemakaian berlebihan, bukan pengganti rate limit global.
const WINDOW_MS = 10 * 60 * 1000;
const LIMIT = 30;
const hits = new Map();

// Google Load Balancer menambahkan IP klien di AKHIR X-Forwarded-For. Bagian awal bisa diisi klien sendiri,
// jadi yang dipakai adalah nilai terakhir.
function alamatPemanggil(request) {
  const xff = request.headers.get('x-forwarded-for') || '';
  const bagian = xff.split(',').map((x) => x.trim()).filter(Boolean);
  return bagian.length ? bagian[bagian.length - 1] : 'unknown';
}

function izinkan(ip) {
  const now = Date.now();
  if (hits.size > 10000) hits.clear();
  const terbaru = (hits.get(ip) || []).filter((t) => now - t < WINDOW_MS);
  if (terbaru.length >= LIMIT) {
    hits.set(ip, terbaru);
    return false;
  }
  terbaru.push(now);
  hits.set(ip, terbaru);
  return true;
}

function jsonRes(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

export async function handleDemoExtract(request, env) {
  if (!izinkan(alamatPemanggil(request))) {
    return new Response(JSON.stringify({ error: { code: 'RATE_LIMITED', message: 'Terlalu banyak percobaan demo. Coba lagi beberapa menit lagi.', details: null } }), {
      status: 429,
      headers: { 'Content-Type': 'application/json', 'Retry-After': '600', 'Cache-Control': 'no-store' },
    });
  }

  if (!env.DEMO_OCR_BASE || !env.DEMO_OCR_TOKEN) {
    return jsonRes({ error: { code: 'DEMO_UNAVAILABLE', message: 'Mode demo belum tersedia.', details: null } }, 503);
  }

  const kategori = request.headers.get('x-category') || 'auto';
  if (!KATEGORI.has(kategori)) {
    return jsonRes({ error: { code: 'VALIDATION_ERROR', message: 'Kategori tidak dikenal.', details: null } }, 400);
  }

  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0) {
    return jsonRes({ error: { code: 'VALIDATION_ERROR', message: 'Berkas kosong.', details: null } }, 400);
  }
  if (bytes.byteLength > MAX_BYTES) {
    return jsonRes({ error: { code: 'FILE_TOO_LARGE', message: 'Berkas melebihi 10 MB.', details: null } }, 413);
  }

  let upstream;
  try {
    upstream = await fetch(`${env.DEMO_OCR_BASE.replace(/\/$/, '')}/demo/extract`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-Internal-Token': env.DEMO_OCR_TOKEN,
        'X-Category': kategori,
      },
      body: bytes,
    });
  } catch {
    return jsonRes({ error: { code: 'UPSTREAM_ERROR', message: 'Layanan OCR sedang tidak tersedia. Coba lagi nanti.', details: null } }, 502);
  }

  if (upstream.status >= 500) {
    console.error('demo ocr gagal:', upstream.status);
    await upstream.arrayBuffer().catch(() => {});
    return jsonRes({ error: { code: 'UPSTREAM_ERROR', message: 'Layanan OCR sedang bermasalah. Coba lagi nanti.', details: null } }, upstream.status);
  }
  if (!upstream.ok) {
    return jsonRes({ error: { code: 'OCR_FAILED', message: 'Berkas tidak dapat dibaca. Coba foto atau pindai ulang.', details: null } }, upstream.status);
  }
  // Aliran NDJSON diteruskan apa adanya: setiap tahap sampai ke browser saat selesai, bukan menunggu semuanya.
  return new Response(upstream.body, {
    status: 200,
    headers: { 'Content-Type': 'application/x-ndjson', 'Cache-Control': 'no-store' },
  });
}
