// Tes unit untuk handler BFF: routing, sesi, CSRF, penerusan ke API, dan alur undangan.
// fetch global diganti dengan tiruan, sehingga tidak ada panggilan jaringan sungguhan.
import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
import { randomToken, seal } from '../src/crypto.js';
import { SESSION_COOKIE } from '../src/cookies.js';
import { newSession } from '../src/auth.js';

const KEY = randomToken(32);
const env = {
  API_BASE: 'https://api.test',
  COOKIE_KEY: KEY,
  APP_ORIGIN: 'https://YOUR-APP-HOST.web.app',
  APP_ORIGIN_ALT: 'https://YOUR-APP-HOST-ALT.web.app',
  FIREBASE_PROJECT_ID: 'YOUR_FIREBASE_PROJECT_ID',
};

let calls;
let nextResponse;
const realFetch = globalThis.fetch;

beforeEach(() => {
  calls = [];
  nextResponse = () => new Response(JSON.stringify({ data: { ok: true } }), { status: 200, headers: { 'Content-Type': 'application/json', 'Set-Cookie': 'x=1' } });
  globalThis.fetch = async (url, init = {}) => {
    calls.push({ url: String(url), init });
    return nextResponse();
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
});

async function sessionCookieHeader(roles = ['USER']) {
  const t = Math.floor(Date.now() / 1000);
  const session = newSession({ idToken: 'id-token-fiktif', payload: { exp: t + 600, sub: 'u1' }, roles });
  return `${SESSION_COOKIE}=${await seal(session, KEY)}`;
}

async function sessionCsrf(cookie) {
  // Tiruan dari klien: token CSRF berasal dari /bff/me. Di sini diambil langsung dari sesi.
  const { unseal } = await import('../src/crypto.js');
  const value = cookie.slice(`${SESSION_COOKIE}=`.length);
  return (await unseal(value, KEY)).csrf;
}

test('endpoint tanpa sesi dan tanpa Bearer ditolak 401, tanpa memanggil API', async () => {
  const res = await worker.fetch(new Request('https://bff.test/bff/api/v1/documents'), env);

  assert.equal(res.status, 401);
  assert.equal(calls.length, 0);
});

test('GET ke /bff/api diteruskan ke API dengan Bearer dari sesi, bukan cookie', async () => {
  const cookie = await sessionCookieHeader();
  const req = new Request('https://bff.test/bff/api/v1/documents?page=1', { headers: { Cookie: cookie } });

  const res = await worker.fetch(req, env);

  assert.equal(res.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://api.test/api/v1/documents?page=1');
  assert.equal(calls[0].init.headers.get('Authorization'), 'Bearer id-token-fiktif');
  assert.equal(calls[0].init.headers.get('Cookie'), null);
});

test('Set-Cookie dari API tidak diteruskan ke browser', async () => {
  const cookie = await sessionCookieHeader();
  const res = await worker.fetch(new Request('https://bff.test/bff/api/v1/documents', { headers: { Cookie: cookie } }), env);

  const setCookies = res.headers.getSetCookie?.() ?? [];
  assert.ok(!setCookies.some((c) => c.startsWith('x=1')), 'Set-Cookie dari API harus dibuang');
});

test('POST berbasis cookie tanpa X-CSRF-Token ditolak 403 dan tidak sampai ke API', async () => {
  const cookie = await sessionCookieHeader();
  const req = new Request('https://bff.test/bff/api/v1/documents', {
    method: 'POST',
    headers: { Cookie: cookie, 'Content-Type': 'application/json' },
    body: '{}',
  });

  const res = await worker.fetch(req, env);

  assert.equal(res.status, 403);
  assert.equal(calls.length, 0);
});

test('POST berbasis cookie dengan CSRF yang benar diteruskan', async () => {
  const cookie = await sessionCookieHeader();
  const csrf = await sessionCsrf(cookie);
  const req = new Request('https://bff.test/bff/api/v1/documents/abc/reprocess', {
    method: 'POST',
    headers: { Cookie: cookie, 'X-CSRF-Token': csrf, 'Content-Type': 'application/json' },
    body: '{}',
  });

  const res = await worker.fetch(req, env);

  assert.equal(res.status, 200);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].init.method, 'POST');
});

test('header host tidak diteruskan ke API', async () => {
  const cookie = await sessionCookieHeader();
  await worker.fetch(new Request('https://bff.test/bff/api/v1/documents', { headers: { Cookie: cookie, Host: 'bff.test' } }), env);

  assert.notEqual(calls[0].init.headers.get('Host'), 'bff.test');
});

test('origin asing ditolak 403 sebelum apa pun dijalankan', async () => {
  const res = await worker.fetch(new Request('https://bff.test/bff/api/v1/documents', { headers: { Origin: 'https://evil.example' } }), env);

  assert.equal(res.status, 403);
  assert.equal(calls.length, 0);
});

test('path yang tidak dikenal dijawab 404', async () => {
  const res = await worker.fetch(new Request('https://bff.test/bff/tidak-ada'), env);

  assert.equal(res.status, 404);
});

test('cek undangan: token kosong ditolak 410 tanpa memanggil API', async () => {
  const req = new Request('https://bff.test/bff/undangan/cek', { method: 'POST', body: JSON.stringify({}), headers: { 'Content-Type': 'application/json' } });

  const res = await worker.fetch(req, env);

  assert.equal(res.status, 410);
  assert.equal(calls.length, 0);
});

test('cek undangan: token diteruskan ke endpoint publik API', async () => {
  const req = new Request('https://bff.test/bff/undangan/cek', { method: 'POST', body: JSON.stringify({ token: 'tok-fiktif' }), headers: { 'Content-Type': 'application/json' } });

  await worker.fetch(req, env);

  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /\/invitations\/check$/);
  assert.deepEqual(JSON.parse(calls[0].init.body), { token: 'tok-fiktif' });
});

test('selesai undangan: sandi lemah ditolak 400 sebelum API dan Firebase dipanggil', async () => {
  const req = new Request('https://bff.test/bff/undangan/selesai', {
    method: 'POST',
    body: JSON.stringify({ token: 'tok-fiktif', password: 'lemah' }),
    headers: { 'Content-Type': 'application/json' },
  });

  const res = await worker.fetch(req, env);

  assert.equal(res.status, 400);
  assert.equal(calls.length, 0);
});

test('selesai undangan: kegagalan dari API diteruskan apa adanya, sandi tidak disimpan', async () => {
  nextResponse = () => new Response(JSON.stringify({ error: { code: 'INVITATION_INVALID' } }), { status: 410, headers: { 'Content-Type': 'application/json' } });
  const req = new Request('https://bff.test/bff/undangan/selesai', {
    method: 'POST',
    body: JSON.stringify({ token: 'tok-fiktif', password: 'sandi1234', full_name: 'Nama Fiktif', nip: '198503122010011004' }),
    headers: { 'Content-Type': 'application/json' },
  });

  const res = await worker.fetch(req, env);

  assert.equal(res.status, 410);
  assert.equal(calls.length, 1, 'hanya satu panggilan (redeem), tanpa langkah Firebase');
  assert.match(calls[0].url, /\/invitations\/redeem$/);
});
