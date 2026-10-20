// Tes unit untuk perlindungan BFF: sesi, cookie, enkripsi sesi, role, dan kebijakan sandi.
// Dijalankan dengan `npm test` (node:test bawaan, tanpa dependensi tambahan).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomToken, seal, unseal } from '../src/crypto.js';
import { readCookie, setCookie, clearCookie, SESSION_COOKIE } from '../src/cookies.js';
import { rolesFrom, sessionFrom, sessionCookie, newSession, IDLE_SECONDS, ABSOLUTE_SECONDS } from '../src/auth.js';
import { passwordProblem } from '../src/invitation.js';

const KEY = randomToken(32); // 32 byte, base64url, seperti COOKIE_KEY

test('sesi tersegel bisa dibuka dengan kunci yang sama', async () => {
  const sealed = await seal({ a: 1 }, KEY);
  assert.deepEqual(await unseal(sealed, KEY), { a: 1 });
});

test('sesi tidak bisa dibuka dengan kunci lain atau bila dirusak', async () => {
  const sealed = await seal({ a: 1 }, KEY);
  assert.equal(await unseal(sealed, randomToken(32)), null);
  const rusak = sealed.slice(0, -2) + (sealed.endsWith('AA') ? 'BB' : 'AA');
  assert.equal(await unseal(rusak, KEY), null);
});

test('cookie sesi selalu HttpOnly, Secure, dan SameSite=Strict', () => {
  const header = setCookie(SESSION_COOKIE, 'x', 60);
  assert.match(header, /HttpOnly/);
  assert.match(header, /Secure/);
  assert.match(header, /SameSite=Strict/);
  assert.match(clearCookie(SESSION_COOKIE), /Max-Age=0/);
});

test('readCookie membaca nilai yang tepat, dan null bila tidak ada', () => {
  assert.equal(readCookie('a=1; __session=abc; b=2', '__session'), 'abc');
  assert.equal(readCookie('a=1', '__session'), null);
  assert.equal(readCookie(null, '__session'), null);
});

test('role di luar daftar yang diizinkan dibuang', () => {
  assert.deepEqual(rolesFrom({ roles: ['USER', 'SUPERUSER', 'ADMIN'] }), ['USER', 'ADMIN']);
  assert.deepEqual(rolesFrom({}), []);
});

function requestWith(cookieValue) {
  return { headers: new Headers({ Cookie: `${SESSION_COOKIE}=${cookieValue}` }) };
}

test('sesi yang masih segar diterima', async () => {
  const t = Math.floor(Date.now() / 1000);
  const session = { at: 'id', exp: t + 600, iat: t, last: t, sub: 'u1', roles: ['USER'] };
  const sealed = await seal(session, KEY);
  const got = await sessionFrom(requestWith(sealed), KEY);
  assert.equal(got?.sub, 'u1');
});

test('sesi idle lebih dari 30 menit ditolak', async () => {
  const t = Math.floor(Date.now() / 1000);
  const session = { at: 'id', exp: t + 600, iat: t, last: t - IDLE_SECONDS - 60, sub: 'u1', roles: ['USER'] };
  assert.equal(await sessionFrom(requestWith(await seal(session, KEY)), KEY), null);
});

test('sesi melewati batas mutlak 8 jam ditolak meski aktif', async () => {
  const t = Math.floor(Date.now() / 1000);
  const session = { at: 'id', exp: t + 600, iat: t - ABSOLUTE_SECONDS - 60, last: t, sub: 'u1', roles: ['USER'] };
  assert.equal(await sessionFrom(requestWith(await seal(session, KEY)), KEY), null);
});

test('sesi dengan ID token yang sudah kedaluwarsa ditolak', async () => {
  const t = Math.floor(Date.now() / 1000);
  const session = { at: 'id', exp: t - 1, iat: t, last: t, sub: 'u1', roles: ['USER'] };
  assert.equal(await sessionFrom(requestWith(await seal(session, KEY)), KEY), null);
});

test('sessionCookie menghasilkan Set-Cookie yang bisa dibuka lagi', async () => {
  const session = newSession({ idToken: 'id', payload: { exp: Math.floor(Date.now() / 1000) + 600, sub: 'u1' }, roles: ['USER'] });
  const header = await sessionCookie(session, KEY);
  const value = header.split(';')[0].slice(`${SESSION_COOKIE}=`.length);
  assert.equal((await unseal(value, KEY))?.sub, 'u1');
});

test('kebijakan sandi: 8 sampai 128 karakter, memuat huruf dan angka', () => {
  assert.match(passwordProblem('abc1'), /8 sampai 128/);
  assert.match(passwordProblem('abcdefgh'), /huruf dan angka/);
  assert.match(passwordProblem('12345678'), /huruf dan angka/);
  assert.equal(passwordProblem('abcdefg1'), null);
  assert.match(passwordProblem('a1' + 'x'.repeat(127)), /8 sampai 128/);
});
